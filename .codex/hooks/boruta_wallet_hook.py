from __future__ import annotations

import base64
import json
import os
import secrets
import signal
import subprocess
import sys
import tempfile
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa, utils


DEFAULT_OAUTH_BASE_URL = "http://localhost:8080"
DEFAULT_WALLET_SERVER_URL = "http://127.0.0.1:8766/agent/wallet"
DEFAULT_WALLET_SERVER_START_TIMEOUT_SECONDS = 5
DEFAULT_WALLET_SERVER_STOP_TIMEOUT_SECONDS = 5
DEFAULT_AGENT_CREDENTIALS_DIR = "~/.boruta/agent_credentials"


def enabled(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() not in {"", "0", "false", "no", "off"}


def oauth_base_url() -> str:
    return (
        os.getenv("BORUTA_CODEX_HOOK_OAUTH_BASE_URL")
        or os.getenv("BORUTA_OAUTH_BASE_URL")
        or DEFAULT_OAUTH_BASE_URL
    ).rstrip("/")


def browser_timeout() -> float:
    return float(os.getenv("BORUTA_CODEX_HOOK_BROWSER_TIMEOUT", "300"))


def session_marker_path(state_file: str | None) -> Path:
    marker_file = os.getenv("BORUTA_CODEX_HOOK_SESSION_FILE")
    if marker_file:
        return Path(os.path.expanduser(marker_file))
    if state_file:
        return Path(state_file).with_name("codex-hook-session.json")
    return Path(os.path.expanduser("~/.boruta/codex-hook-session.json"))


def wallet_server_marker_path(state_file: str | None) -> Path:
    marker_file = os.getenv("BORUTA_CODEX_HOOK_WALLET_SERVER_SESSION_FILE")
    if marker_file:
        return Path(os.path.expanduser(marker_file))
    return session_marker_path(state_file).with_name("codex-hook-wallet-server-session.json")


def wallet_server_log_path(state_file: str | None) -> Path:
    log_file = os.getenv("BORUTA_CODEX_HOOK_WALLET_SERVER_LOG_FILE")
    if log_file:
        return Path(os.path.expanduser(log_file))
    return session_marker_path(state_file).with_name("codex-hook-wallet-server.log")


def read_process_marker(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def write_process_marker(path: Path, session_id: str, root: Path, pid: int, log_file: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump({
                "session_id": session_id,
                "repo_root": str(root),
                "pid": pid,
                "url": wallet_server_url(),
                "log_file": str(log_file),
                "updated_at": int(time.time()),
            }, tmp, indent=2)
            tmp.write("\n")
            tmp.flush()
            os.fsync(tmp.fileno())
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def process_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def terminate_process(pid: int, timeout: float) -> None:
    if not process_running(pid):
        return
    os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not process_running(pid):
            return
        time.sleep(0.1)
    if process_running(pid):
        os.kill(pid, signal.SIGKILL)


def wallet_server_url() -> str:
    return os.getenv("BORUTA_CODEX_HOOK_WALLET_SERVER_URL", DEFAULT_WALLET_SERVER_URL)


def authorization_server_jwks_url() -> str:
    return os.getenv("BORUTA_CODEX_HOOK_JWKS_URL", f"{oauth_base_url()}/openid/jwks")


def wallet_server_enabled() -> bool:
    return enabled("BORUTA_CODEX_HOOK_WALLET_SERVER", default=False)


def wallet_server_host() -> str | None:
    return os.getenv("BORUTA_CODEX_HOOK_WALLET_SERVER_HOST")


def wallet_server(root: Path, wallet_url: str, callback: Any | None = None) -> HTTPServer:
    parsed = urlparse(wallet_url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or not parsed.port:
        raise RuntimeError("wallet server URL must include an http host and explicit port")

    class WalletHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            query = parse_qs(urlparse(self.path).query)
            error = first_query_value(query, "error_description") or first_query_value(query, "error")

            if error:
                if callback:
                    callback.set_error(error)
                self.respond_html(f"Wallet request failed: {error}", status=400)
                return

            try:
                redirect_uri = wallet_redirect_uri(query)
                if not redirect_uri:
                    self.respond_html("Wallet request did not include a redirect_uri.", status=400)
                    return
                post_wallet_response(root, query)
            except Exception as error:
                message = exception_message(error)
                if callback:
                    callback.set_error(f"wallet direct_post failed: {message}")
                self.respond_html(f"Wallet direct_post failed: {message}", status=502)
                return

            self.respond_html("Wallet response posted. You can close this tab.")

        def log_message(self, _format: str, *_args: object) -> None:
            return

        def respond_html(self, body: str, status: int = 200) -> None:
            content = (
                "<!doctype html><meta charset='utf-8'>"
                f"<title>Boruta Codex wallet</title><p>{body}</p>"
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("content-type", "text/html; charset=utf-8")
            self.send_header("content-length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

    return HTTPServer((wallet_server_host() or parsed.hostname, parsed.port), WalletHandler)


def post_wallet_response(root: Path, query: dict[str, list[str]]) -> None:
    response_type = first_query_value(query, "response_type") or ""
    redirect_uri = wallet_redirect_uri(query)
    if not redirect_uri:
        raise RuntimeError("Wallet request did not include a redirect_uri.")

    parameters: dict[str, str]
    if "vp_token" in response_type.split():
        vp_token, presentation_submission = wallet_vp_token(root, query)
        parameters = {
            "vp_token": vp_token,
            "presentation_submission": presentation_submission,
        }
    else:
        parameters = {"id_token": wallet_id_token(root)}

    client_id = os.getenv("BORUTA_CODEX_HOOK_CLIENT_ID")
    client_secret = os.getenv("BORUTA_CODEX_HOOK_CLIENT_SECRET")
    if client_id:
        parameters["client_id"] = client_id
    if client_secret:
        parameters["client_secret"] = client_secret

    request = Request(
        redirect_uri,
        data=urlencode(parameters).encode("utf-8"),
        headers={"content-type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urlopen(request, timeout=browser_timeout()) as response:
        response.read()


def exception_message(error: Exception) -> str:
    if isinstance(error, HTTPError):
        body = error.read().decode("utf-8", errors="replace").strip()
        details = f"status={error.code}"
        if error.reason:
            details = f"{details} reason={error.reason}"
        if body:
            details = f"{details} body={body}"
        return details
    if isinstance(error, URLError):
        reason = getattr(error, "reason", None)
        return f"{type(error).__name__}: {reason or error}"
    message = str(error).strip()
    return f"{type(error).__name__}: {message}" if message else type(error).__name__


def wallet_id_token(root: Path) -> str:
    scripts_path = root / "scripts"
    sys.path.insert(0, str(scripts_path))
    try:
        from agent_session_authorize import actor_id_token, parse_actor
    finally:
        try:
            sys.path.remove(str(scripts_path))
        except ValueError:
            pass

    actor = parse_actor(os.getenv("BORUTA_CODEX_HOOK_WALLET_ACTOR", "user:codex-wallet"))
    return actor_id_token(actor, "oid4vp_wallet_response")


def wallet_vp_token(root: Path, query: dict[str, list[str]]) -> tuple[str, str]:
    claims = wallet_request_claims(query) or {}
    presentation_definition = wallet_presentation_definition(query)
    credential_path = wallet_credential_path(presentation_definition)
    credential = credential_path.read_text(encoding="utf-8").strip()
    if not credential:
        raise RuntimeError(f"credential file is empty: {credential_path}")

    presentation_submission = {
        "id": f"codex_hook_input_submission_{credential_path.stem}",
        "definition_id": presentation_definition.get("id", f"codex_hook_input_{credential_path.stem}"),
        "descriptor_map": [
            {
                "id": "codex_hook_input",
                "format": "jwt_vc",
                "path": "$.vp.verifiableCredential[0]",
            }
        ],
    }

    nonce = claims.get("nonce") if isinstance(claims.get("nonce"), str) else None
    audience = claims.get("aud") if isinstance(claims.get("aud"), str) else None

    return wallet_vp_token_for_credential(root, credential, nonce, audience), json.dumps(
        presentation_submission,
        separators=(",", ":"),
    )


def wallet_request_claims(query: dict[str, list[str]]) -> dict[str, Any] | None:
    request = first_query_value(query, "request")
    if not request:
        return None
    return verify_authorization_request_jwt(request)


def wallet_redirect_uri(query: dict[str, list[str]]) -> str | None:
    claims = wallet_request_claims(query)
    if not claims:
        return None
    redirect_uri = claims.get("redirect_uri")
    return redirect_uri if isinstance(redirect_uri, str) and redirect_uri else None


def wallet_presentation_definition(query: dict[str, list[str]]) -> dict[str, Any]:
    claims = wallet_request_claims(query)
    if claims:
        definition = claims.get("presentation_definition")
        if not isinstance(definition, dict):
            raise RuntimeError("request JWT presentation_definition is not a JSON object.")
        return definition

    raise RuntimeError("presentation_definition must be present.")


def verify_authorization_request_jwt(jwt: str) -> dict[str, Any]:
    signing_input, header, payload, signature = split_jwt(jwt)
    alg = header.get("alg")
    if not isinstance(alg, str):
        raise RuntimeError("Request JWT does not include an alg header.")

    jwks = fetch_authorization_server_jwks()
    keys = jwks.get("keys")
    if not isinstance(keys, list):
        raise RuntimeError("Authorization server JWKS did not include a keys array.")

    kid = header.get("kid")
    candidates = [
        key for key in keys
        if isinstance(key, dict) and (not kid or key.get("kid") == kid)
    ]
    if not candidates:
        raise RuntimeError("Authorization server JWKS did not include a matching key.")

    for jwk in candidates:
        if verify_jws_signature(alg, signing_input, signature, jwk):
            validate_jwt_times(payload)
            return payload

    raise RuntimeError("Request JWT signature could not be verified with authorization server JWKS.")


def fetch_authorization_server_jwks() -> dict[str, Any]:
    request = Request(authorization_server_jwks_url(), method="GET")
    with urlopen(request, timeout=browser_timeout()) as response:
        body = response.read().decode("utf-8")
    jwks = json.loads(body)
    if not isinstance(jwks, dict):
        raise RuntimeError("Authorization server JWKS response is not a JSON object.")
    return jwks


def split_jwt(jwt: str) -> tuple[bytes, dict[str, Any], dict[str, Any], bytes]:
    parts = jwt.split(".")
    if len(parts) != 3:
        raise RuntimeError("Request JWT is malformed.")
    header = json.loads(base64_url_decode(parts[0]).decode("utf-8"))
    payload = json.loads(base64_url_decode(parts[1]).decode("utf-8"))
    if not isinstance(header, dict) or not isinstance(payload, dict):
        raise RuntimeError("Request JWT header or payload is not a JSON object.")
    return f"{parts[0]}.{parts[1]}".encode("ascii"), header, payload, base64_url_decode(parts[2])


def base64_url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii"))


def validate_jwt_times(payload: dict[str, Any]) -> None:
    now = int(time.time())
    exp = payload.get("exp")
    if exp is not None and isinstance(exp, (int, float)) and int(exp) < now:
        raise RuntimeError("Request JWT is expired.")
    nbf = payload.get("nbf")
    if nbf is not None and isinstance(nbf, (int, float)) and int(nbf) > now:
        raise RuntimeError("Request JWT is not valid yet.")


def verify_jws_signature(alg: str, signing_input: bytes, signature: bytes, jwk: dict[str, Any]) -> bool:
    kty = jwk.get("kty")
    try:
        if kty == "RSA":
            return verify_rsa_jws_signature(alg, signing_input, signature, jwk)
        if kty == "EC":
            return verify_ec_jws_signature(alg, signing_input, signature, jwk)
    except (KeyError, TypeError, ValueError, InvalidSignature):
        return False
    return False


def verify_rsa_jws_signature(alg: str, signing_input: bytes, signature: bytes, jwk: dict[str, Any]) -> bool:
    hash_algorithm = jws_hash_algorithm(alg)
    if alg.startswith("RS"):
        signature_padding = padding.PKCS1v15()
    elif alg.startswith("PS"):
        signature_padding = padding.PSS(
            mgf=padding.MGF1(hash_algorithm),
            salt_length=hash_algorithm.digest_size,
        )
    else:
        return False

    public_numbers = rsa.RSAPublicNumbers(
        e=int.from_bytes(base64_url_decode(str(jwk["e"])), "big"),
        n=int.from_bytes(base64_url_decode(str(jwk["n"])), "big"),
    )
    public_numbers.public_key().verify(signature, signing_input, signature_padding, hash_algorithm)
    return True


def verify_ec_jws_signature(alg: str, signing_input: bytes, signature: bytes, jwk: dict[str, Any]) -> bool:
    curve, coordinate_size = jws_ec_curve(alg, str(jwk.get("crv") or ""))
    if len(signature) != coordinate_size * 2:
        return False

    x = int.from_bytes(base64_url_decode(str(jwk["x"])), "big")
    y = int.from_bytes(base64_url_decode(str(jwk["y"])), "big")
    r = int.from_bytes(signature[:coordinate_size], "big")
    s = int.from_bytes(signature[coordinate_size:], "big")
    der_signature = utils.encode_dss_signature(r, s)

    public_numbers = ec.EllipticCurvePublicNumbers(x=x, y=y, curve=curve)
    public_numbers.public_key().verify(
        der_signature,
        signing_input,
        ec.ECDSA(jws_hash_algorithm(alg)),
    )
    return True


def jws_hash_algorithm(alg: str) -> hashes.HashAlgorithm:
    if alg.endswith("256"):
        return hashes.SHA256()
    if alg.endswith("384"):
        return hashes.SHA384()
    if alg.endswith("512"):
        return hashes.SHA512()
    raise ValueError(f"Unsupported request JWT signature algorithm: {alg}")


def jws_ec_curve(alg: str, crv: str) -> tuple[ec.EllipticCurve, int]:
    if alg == "ES256" and crv == "P-256":
        return ec.SECP256R1(), 32
    if alg == "ES384" and crv == "P-384":
        return ec.SECP384R1(), 48
    if alg == "ES512" and crv == "P-521":
        return ec.SECP521R1(), 66
    raise ValueError(f"Unsupported EC request JWT key: alg={alg}, crv={crv}")


def wallet_credential_path(presentation_definition: dict[str, Any]) -> Path:
    credential_filename = wallet_credential_filename(presentation_definition)
    if credential_filename:
        path = agent_credentials_dir() / credential_filename
        if path.is_file():
            return path
        raise RuntimeError(f"credential file not found: {path}")

    credentials = sorted(agent_credentials_dir().glob("*.jwt"), key=lambda path: path.stat().st_mtime)
    if not credentials:
        raise RuntimeError(f"no credentials found in {agent_credentials_dir()}")
    return credentials[-1]


def wallet_credential_filename(presentation_definition: dict[str, Any]) -> str | None:
    for descriptor in presentation_definition.get("input_descriptors", []):
        constraints = descriptor.get("constraints", {}) if isinstance(descriptor, dict) else {}
        for field in constraints.get("fields", []):
            if not isinstance(field, dict):
                continue
            if "$.credential_filename" not in field.get("path", []):
                continue
            const = field.get("filter", {}).get("const")
            if isinstance(const, str) and const:
                return const
    return None


def wallet_vp_token_for_credential(
    root: Path,
    credential: str,
    nonce: str | None = None,
    audience: str | None = None,
) -> str:
    scripts_path = root / "scripts"
    sys.path.insert(0, str(scripts_path))
    try:
        from agent_session_authorize import (
            SIGNATURE_ALG,
            base64_url,
            base64_url_json,
            ensure_private_key,
            ensure_public_jwk,
            parse_actor,
            sign_es256,
        )
    finally:
        try:
            sys.path.remove(str(scripts_path))
        except ValueError:
            pass

    actor = parse_actor(os.getenv("BORUTA_CODEX_HOOK_WALLET_ACTOR", "user:codex-wallet"))
    ensure_private_key(actor)
    jwk = ensure_public_jwk(actor)
    now = int(time.time())
    header = {"alg": SIGNATURE_ALG, "typ": "JWT", "kid": actor.actor_id, "jwk": jwk}
    payload = {
        "iss": actor.actor_id,
        "sub": actor.actor_id,
        "iat": now,
        "exp": now + 300,
        "vp": {
            "@context": ["https://www.w3.org/2018/credentials/v1"],
            "type": ["VerifiablePresentation"],
            "verifiableCredential": [credential],
        },
    }
    if nonce:
        payload["nonce"] = nonce
    if audience:
        payload["aud"] = audience
    signing_input = f"{base64_url_json(header)}.{base64_url_json(payload)}"
    signature = sign_es256(actor.private_key_path, signing_input.encode("ascii"))
    return f"{signing_input}.{base64_url(signature)}"


def agent_credentials_dir() -> Path:
    return Path(os.path.expanduser(os.getenv(
        "BORUTA_AGENT_CREDENTIALS_DIR",
        DEFAULT_AGENT_CREDENTIALS_DIR,
    )))


def ensure_agent_credentials_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    os.chmod(path, 0o700)


def hook_input_credential(
    root: Path,
    hook_input: dict[str, Any],
    credential_filename: str,
    actor: str,
    event_kind: str,
) -> str:
    scripts_path = root / "scripts"
    sys.path.insert(0, str(scripts_path))
    try:
        from agent_session_authorize import (
            SIGNATURE_ALG,
            base64_url,
            base64_url_json,
            ensure_private_key,
            ensure_public_jwk,
            parse_actor,
            sign_es256,
        )
    finally:
        try:
            sys.path.remove(str(scripts_path))
        except ValueError:
            pass

    parsed_actor = parse_actor(actor)
    ensure_private_key(parsed_actor)
    jwk = ensure_public_jwk(parsed_actor)
    now = int(time.time())
    header = {"alg": SIGNATURE_ALG, "typ": "JWT", "kid": parsed_actor.actor_id, "jwk": jwk}
    payload = {
        "iss": parsed_actor.actor_id,
        "sub": parsed_actor.actor_id,
        "actor_type": parsed_actor.actor_type,
        "event": event_kind,
        "iat": now,
        "jti": secrets.token_urlsafe(32),
        "credential_type": "codex_hook_input",
        "credential_filename": credential_filename,
        "user_data": hook_input,
    }
    signing_input = f"{base64_url_json(header)}.{base64_url_json(payload)}"
    signature = sign_es256(parsed_actor.private_key_path, signing_input.encode("ascii"))
    return f"{signing_input}.{base64_url(signature)}"


def store_hook_input_credential(
    root: Path,
    hook_input: dict[str, Any],
    actor: str,
    event_kind: str,
) -> Path:
    directory = agent_credentials_dir()
    ensure_agent_credentials_dir(directory)
    for _ in range(10):
        path = directory / f"{secrets.token_urlsafe(24)}.jwt"
        credential = hook_input_credential(root, hook_input, path.name, actor, event_kind)
        try:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            continue
        with os.fdopen(fd, "w", encoding="utf-8") as credential_file:
            credential_file.write(credential)
            credential_file.write("\n")
            credential_file.flush()
            os.fsync(credential_file.fileno())
        return path
    raise RuntimeError(f"could not create unique credential file in {directory}")


def hook_input_presentation_definition(credential_path: Path) -> dict[str, Any]:
    return {
        "id": f"codex_hook_input_{credential_path.stem}",
        "input_descriptors": [
            {
                "id": "codex_hook_input",
                "name": "Codex hook input",
                "format": {"jwt_vc": {}},
                "constraints": {
                    "fields": [
                        {
                            "path": ["$.credential_type"],
                            "filter": {"type": "string", "const": "codex_hook_input"},
                        },
                        {
                            "path": ["$.credential_filename"],
                            "filter": {"type": "string", "const": credential_path.name},
                        },
                    ],
                },
            },
        ],
    }


def agent_wallet_url() -> str:
    return wallet_server_url()


def serialized_hook_presentation_definition(credential_path: Path) -> str:
    return json.dumps(
        hook_input_presentation_definition(credential_path),
        separators=(",", ":"),
    )


def append_query(url: str, query: str) -> str:
    if not query:
        return url
    separator = "&" if urlparse(url).query else "?"
    return f"{url}{separator}{query}"


def serve_wallet_server(root: Path) -> int:
    server = wallet_server(root, wallet_server_url())
    try:
        server.serve_forever()
    finally:
        server.server_close()
    return 0


def wallet_server_stop_timeout() -> float:
    return float(os.getenv(
        "BORUTA_CODEX_HOOK_WALLET_SERVER_STOP_TIMEOUT",
        str(DEFAULT_WALLET_SERVER_STOP_TIMEOUT_SECONDS),
    ))


def wallet_server_start_timeout() -> float:
    return float(os.getenv(
        "BORUTA_CODEX_HOOK_WALLET_SERVER_START_TIMEOUT",
        str(DEFAULT_WALLET_SERVER_START_TIMEOUT_SECONDS),
    ))


def wallet_server_reachable(url: str) -> bool:
    try:
        request = Request(url, method="GET")
        with urlopen(request, timeout=0.5) as response:
            response.read()
        return True
    except HTTPError:
        return True
    except (OSError, URLError):
        return False


def tail_file(path: Path, max_bytes: int = 4096) -> str:
    try:
        with path.open("rb") as file:
            file.seek(0, os.SEEK_END)
            size = file.tell()
            file.seek(max(0, size - max_bytes))
            return file.read().decode("utf-8", errors="replace").strip()
    except OSError:
        return ""


def wait_for_wallet_server(process: subprocess.Popen[bytes], url: str, log_file: Path) -> str | None:
    deadline = time.monotonic() + wallet_server_start_timeout()
    while time.monotonic() < deadline:
        returncode = process.poll()
        if returncode is not None:
            details = tail_file(log_file)
            suffix = f": {details.splitlines()[-1]}" if details else ""
            return f"Wallet server startup failed: child exited with status {returncode}{suffix}"

        if wallet_server_reachable(url):
            time.sleep(0.1)
            returncode = process.poll()
            if returncode is not None:
                details = tail_file(log_file)
                suffix = f": {details.splitlines()[-1]}" if details else ""
                return f"Wallet server startup failed: child exited with status {returncode}{suffix}"
            return None

        time.sleep(0.1)

    if process.poll() is None:
        terminate_process(process.pid, wallet_server_stop_timeout())
    return f"Wallet server startup failed: timed out waiting for {url}"


def should_start_wallet_server(
    hook_input: dict[str, Any],
    marker: dict[str, Any] | None,
    session_id: str,
) -> bool:
    event = hook_input.get("hook_event_name")
    if event in {"SessionStart", "UserPromptSubmit"}:
        return True
    if event == "Stop":
        return False
    return bool(marker and marker.get("session_id") == session_id)


def start_session_wallet_server(
    hook_input: dict[str, Any],
    root: Path,
    state_file: str | None,
    session_id: str,
) -> str | None:
    if not wallet_server_enabled():
        return None

    marker_path = wallet_server_marker_path(state_file)
    log_file = wallet_server_log_path(state_file)
    marker = read_process_marker(marker_path)
    if not should_start_wallet_server(hook_input, marker, session_id):
        return None

    if marker:
        pid = marker.get("pid")
        if isinstance(pid, int) and process_running(pid):
            if wallet_server_reachable(wallet_server_url()):
                if marker.get("session_id") != session_id:
                    write_process_marker(marker_path, session_id, root, pid, log_file)
                return None
            return "Wallet server startup failed: marker process is running but the wallet URL is not reachable"

    if wallet_server_reachable(wallet_server_url()):
        return None

    log_file.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["BORUTA_CODEX_HOOK_SERVE_WALLET_SERVER"] = "true"
    env["BORUTA_CODEX_HOOK_REPO_ROOT"] = str(root)
    try:
        with log_file.open("ab") as log:
            process = subprocess.Popen(
                [sys.executable, str(Path(__file__).resolve())],
                cwd=str(root),
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
    except OSError as error:
        return f"Wallet server startup failed: {type(error).__name__}: {error}"

    startup_error = wait_for_wallet_server(process, wallet_server_url(), log_file)
    if startup_error:
        return startup_error

    write_process_marker(marker_path, session_id, root, process.pid, log_file)
    return None


def stop_session_wallet_server(
    hook_input: dict[str, Any],
    root: Path,
    state_file: str | None,
    session_id: str,
) -> str | None:
    if hook_input.get("hook_event_name") != "Stop":
        return None
    if not wallet_server_enabled():
        return None

    marker_path = wallet_server_marker_path(state_file)
    marker = read_process_marker(marker_path)
    if not marker:
        return None

    if marker.get("session_id") != session_id:
        return None

    pid = marker.get("pid")
    if not isinstance(pid, int):
        return "Wallet server shutdown skipped: invalid PID marker"

    try:
        terminate_process(pid, wallet_server_stop_timeout())
        marker_path.unlink(missing_ok=True)
    except OSError as error:
        return f"Wallet server shutdown failed: {type(error).__name__}: {error}"

    return None


def first_query_value(values: dict[str, list[str]], key: str) -> str | None:
    value = values.get(key)
    return value[0] if value else None


def main() -> int:
    if enabled("BORUTA_CODEX_HOOK_SERVE_WALLET_SERVER", default=False):
        root = Path(os.getenv("BORUTA_CODEX_HOOK_REPO_ROOT") or os.getcwd()).resolve()
        return serve_wallet_server(root)
    print(json.dumps({"systemMessage": "Boruta wallet hook has no standalone action."}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
