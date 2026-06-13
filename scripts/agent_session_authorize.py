from __future__ import annotations

import argparse
import base64
import json
import os
import re
import stat
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE_URL = os.getenv("BORUTA_OAUTH_BASE_URL", "http://localhost:8080").rstrip("/")
CLIENT_ID = os.getenv(
    "BORUTA_AGENT_CHAT_CLIENT_ID", "00000000-0000-0000-0000-000000000001"
)
CLIENT_SECRET = os.getenv("BORUTA_AGENT_CHAT_CLIENT_SECRET", "")
TOKEN_TARGET = os.getenv("BORUTA_AGENT_CHAT_TOKEN_TARGET", f"{BASE_URL}/oauth/token")
GRANT_TYPE = os.getenv("BORUTA_AGENT_SESSION_GRANT_TYPE", "code_chain")
DEFAULT_SCOPE = os.getenv("BORUTA_AGENT_SESSION_SCOPE", os.getenv("BORUTA_AGENT_CHAT_SCOPE", ""))
KEYS_DIR = Path(os.path.expanduser(os.getenv("BORUTA_AGENT_CHAT_KEYS_DIR", "~/.boruta/keys")))
TOKEN_TIMEOUT_SECONDS = float(os.getenv("BORUTA_AGENT_CHAT_TOKEN_TIMEOUT", "5"))
DEFAULT_STATE_FILE = Path(os.path.expanduser(
    os.getenv("BORUTA_AGENT_SESSION_STATE_FILE", "~/.boruta/session-code-chain.json")
))
SIGNATURE_ALG = "ES256"
EC_OPENSSL_CURVE = "prime256v1"
EC_JWK_CURVE = "P-256"
EC_COORDINATE_BYTES = 32


ACTOR_TYPES = {"user", "assistant", "agent", "tool", "external_service"}


@dataclass(frozen=True)
class Actor:
    actor_type: str
    actor_id: str

    @property
    def private_key_path(self) -> Path:
        return KEYS_DIR / f"{self.actor_type}-{self.actor_id}-private-key.pem"

    @property
    def public_jwk_path(self) -> Path:
        return KEYS_DIR / f"{self.actor_type}-{self.actor_id}-public-jwk.json"


def normalize_actor_id(actor_type: str, raw_name: str) -> str:
    name = raw_name.strip().lower()
    name = re.sub(r"[^a-z0-9]+", "-", name)
    name = re.sub(r"-+", "-", name).strip("-")
    if not name:
        raise ValueError("actor name normalizes to an empty id")
    prefix = actor_type.replace("_", "-")
    return name if name.startswith(f"{prefix}-") else f"{prefix}-{name}"


def parse_actor(value: str) -> Actor:
    if ":" not in value:
        raise ValueError("actor must be formatted as <actor_type>:<name>")
    actor_type, raw_name = value.split(":", 1)
    if actor_type not in ACTOR_TYPES:
        raise ValueError(f"unsupported actor_type {actor_type!r}; expected one of {sorted(ACTOR_TYPES)}")
    return Actor(actor_type=actor_type, actor_id=normalize_actor_id(actor_type, raw_name))


def ensure_keys_dir() -> None:
    KEYS_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(KEYS_DIR, 0o700)
    mode = stat.S_IMODE(KEYS_DIR.stat().st_mode)
    if mode != 0o700:
        raise RuntimeError(f"{KEYS_DIR} must have mode 0700, got {mode:o}")


def validate_private_key_permissions(path: Path) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    if mode != 0o600:
        raise RuntimeError(f"{path} must have mode 0600, got {mode:o}")


def run_openssl(args: list[str], input_bytes: bytes | None = None) -> bytes:
    result = subprocess.run(
        ["openssl", *args],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def read_der_length(der: bytes, offset: int) -> tuple[int, int]:
    if offset >= len(der):
        raise ValueError("missing DER length")
    first = der[offset]
    offset += 1
    if first < 0x80:
        return first, offset
    length_bytes = first & 0x7F
    if length_bytes == 0 or length_bytes > 4 or offset + length_bytes > len(der):
        raise ValueError("invalid DER length")
    return int.from_bytes(der[offset:offset + length_bytes], "big"), offset + length_bytes


def read_der_value(der: bytes, offset: int, expected_tag: int) -> tuple[bytes, int]:
    if offset >= len(der) or der[offset] != expected_tag:
        raise ValueError(f"expected DER tag 0x{expected_tag:02x}")
    length, value_offset = read_der_length(der, offset + 1)
    end = value_offset + length
    if end > len(der):
        raise ValueError("truncated DER value")
    return der[value_offset:end], end


def atomic_write(path: Path, data: bytes, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as tmp:
            tmp.write(data)
            tmp.flush()
            os.fsync(tmp.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def private_key_is_ec_p256(path: Path) -> bool:
    try:
        output = run_openssl(["ec", "-in", str(path), "-noout", "-text"])
    except RuntimeError:
        return False
    return f"ASN1 OID: {EC_OPENSSL_CURVE}".encode("ascii") in output


def ensure_private_key(actor: Actor) -> None:
    ensure_keys_dir()
    if actor.private_key_path.exists():
        validate_private_key_permissions(actor.private_key_path)
        if private_key_is_ec_p256(actor.private_key_path):
            return
        actor.private_key_path.unlink()
        if actor.public_jwk_path.exists():
            actor.public_jwk_path.unlink()

    pem = run_openssl(["ecparam", "-name", EC_OPENSSL_CURVE, "-genkey", "-noout"])
    atomic_write(actor.private_key_path, pem, 0o600)
    validate_private_key_permissions(actor.private_key_path)


def base64_url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def base64_url_json(payload: dict[str, object]) -> str:
    return base64_url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))


def ec_public_jwk(private_key_path: Path) -> dict[str, str]:
    der = run_openssl(["ec", "-in", str(private_key_path), "-pubout", "-conv_form", "uncompressed", "-outform", "DER"])
    sequence, end = read_der_value(der, 0, 0x30)
    if end != len(der):
        raise ValueError("unexpected trailing public key DER data")

    _, offset = read_der_value(sequence, 0, 0x30)
    bit_string, offset = read_der_value(sequence, offset, 0x03)
    if offset != len(sequence) or not bit_string or bit_string[0] != 0:
        raise ValueError("invalid EC public key BIT STRING")

    point = bit_string[1:]
    if len(point) != 1 + (EC_COORDINATE_BYTES * 2) or point[0] != 0x04:
        raise ValueError("expected uncompressed P-256 public key point")

    return {
        "kty": "EC",
        "crv": EC_JWK_CURVE,
        "x": base64_url(point[1:1 + EC_COORDINATE_BYTES]),
        "y": base64_url(point[1 + EC_COORDINATE_BYTES:]),
        "alg": SIGNATURE_ALG,
        "use": "sig",
    }


def ensure_public_jwk(actor: Actor) -> dict[str, str]:
    if actor.public_jwk_path.exists():
        os.chmod(actor.public_jwk_path, 0o644)
        jwk = json.loads(actor.public_jwk_path.read_text(encoding="utf-8"))
        if jwk.get("kty") == "EC" and jwk.get("crv") == EC_JWK_CURVE and jwk.get("alg") == SIGNATURE_ALG:
            return jwk
        actor.public_jwk_path.unlink()

    jwk = ec_public_jwk(actor.private_key_path)
    atomic_write(
        actor.public_jwk_path,
        json.dumps(jwk, indent=2).encode("utf-8") + b"\n",
        0o644,
    )
    return jwk


def ecdsa_integer_to_fixed_width(value: bytes) -> bytes:
    value = value.lstrip(b"\x00")
    if len(value) > EC_COORDINATE_BYTES:
        raise ValueError("ECDSA signature integer is too large")
    return value.rjust(EC_COORDINATE_BYTES, b"\x00")


def der_ecdsa_signature_to_raw(signature: bytes) -> bytes:
    sequence, end = read_der_value(signature, 0, 0x30)
    if end != len(signature):
        raise ValueError("unexpected trailing ECDSA signature data")
    r, offset = read_der_value(sequence, 0, 0x02)
    s, offset = read_der_value(sequence, offset, 0x02)
    if offset != len(sequence):
        raise ValueError("unexpected ECDSA signature sequence data")
    return ecdsa_integer_to_fixed_width(r) + ecdsa_integer_to_fixed_width(s)


def sign_es256(private_key_path: Path, signing_input: bytes) -> bytes:
    signature = run_openssl(
        ["dgst", "-sha256", "-sign", str(private_key_path)],
        input_bytes=signing_input,
    )
    return der_ecdsa_signature_to_raw(signature)


def actor_id_token(actor: Actor, event_kind: str, user_prompt: str | None = None) -> str:
    ensure_private_key(actor)
    jwk = ensure_public_jwk(actor)
    now = int(time.time())
    header = {"alg": SIGNATURE_ALG, "typ": "JWT", "kid": actor.actor_id, "jwk": jwk}
    payload = {
        "sub": actor.actor_id,
        "actor_type": actor.actor_type,
        "event": event_kind,
        "iat": now,
        "exp": now + 60,
    }
    if user_prompt:
        payload["user_prompt"] = user_prompt
    signing_input = f"{base64_url_json(header)}.{base64_url_json(payload)}"
    signature = sign_es256(actor.private_key_path, signing_input.encode("ascii"))
    return f"{signing_input}.{base64_url(signature)}"


def truncate(value: str) -> str:
    if len(value) <= 18:
        return value
    return f"{value[:8]}...{value[-8:]}"


def redact_parameters(parameters: dict[str, str]) -> dict[str, str]:
    redacted = dict(parameters)
    for key in ("id_token", "authorization_code"):
        if key in redacted:
            redacted[key] = truncate(redacted[key])
    if "client_secret" in redacted:
        redacted["client_secret"] = "<redacted>"
    return redacted


def print_event(event: str, payload: dict[str, object]) -> None:
    print(json.dumps({"event": event, **payload}, indent=2), flush=True)


def read_previous_code(state_file: Path) -> str | None:
    if not state_file.exists():
        return None
    state = json.loads(state_file.read_text(encoding="utf-8"))
    code = state.get("authorization_code")
    return code if isinstance(code, str) and code else None


def write_next_code(state_file: Path, actor: Actor, event_kind: str, authorization_code: str) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(state_file.parent, 0o700)
    atomic_write(
        state_file,
        json.dumps({
            "authorization_code": authorization_code,
            "authorization_code_preview": truncate(authorization_code),
            "actor_type": actor.actor_type,
            "actor_id": actor.actor_id,
            "event_kind": event_kind,
            "grant_type": GRANT_TYPE,
            "token_endpoint": TOKEN_TARGET,
            "updated_at": int(time.time()),
        }, indent=2).encode("utf-8") + b"\n",
        0o600,
    )


def exchange_code(
    actor: Actor,
    id_token: str,
    previous_authorization_code: str | None,
    scope: str | None,
    show_request: bool,
) -> str:
    parameters = {
        "client_id": CLIENT_ID,
        "grant_type": GRANT_TYPE,
        "id_token": id_token,
    }
    if previous_authorization_code:
        parameters["authorization_code"] = previous_authorization_code
    if scope:
        parameters["scope"] = scope
    if CLIENT_SECRET:
        parameters["client_secret"] = CLIENT_SECRET

    if show_request:
        print_event("boruta_token_request", {
            "request": {
                "method": "POST",
                "url": TOKEN_TARGET,
                "headers": {"content-type": "application/x-www-form-urlencoded"},
                "body": redact_parameters(parameters),
            }
        })

    request_body = urlencode(parameters).encode("utf-8")
    request = Request(
        TOKEN_TARGET,
        data=request_body,
        headers={"content-type": "application/x-www-form-urlencoded"},
        method="POST",
    )

    try:
        with urlopen(request, timeout=TOKEN_TIMEOUT_SECONDS) as response:
            status = response.status
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        if show_request:
            print_event("boruta_token_response", {
                "response": {
                    "status": error.code,
                    "body": body,
                }
            })
        raise RuntimeError(f"token call failed: status={error.code} body={body}") from error
    except (URLError, TimeoutError, json.JSONDecodeError) as error:
        raise RuntimeError(f"token call failed: {error}") from error

    authorization_code = payload.get("authorization_code")
    if not isinstance(authorization_code, str) or not authorization_code:
        raise RuntimeError(f"token response missing authorization_code: {payload}")
    if show_request:
        print_event("boruta_token_response", {
            "response": {
                "status": status,
                "body": {
                    **payload,
                    "authorization_code": truncate(authorization_code),
                },
            }
        })
    return authorization_code


def main() -> None:
    parser = argparse.ArgumentParser(description="Authorize one Codex actor step through Boruta code chaining.")
    parser.add_argument("--actor", required=True, help="Actor formatted as <actor_type>:<name>, e.g. assistant:codex")
    parser.add_argument("--previous-code", help="Previous Boruta authorization code. If omitted, no authorization_code parameter is sent.")
    parser.add_argument("--event-kind", default="tool_call")
    parser.add_argument("--user-prompt", help="User prompt to include in the minted id_token claims")
    parser.add_argument("--scope", default=DEFAULT_SCOPE, help="OAuth scope to include in the token request")
    parser.add_argument("--dry-run", action="store_true", help="Create/validate keys and mint id_token, but do not call Boruta")
    parser.add_argument("--show-request", action="store_true", help="Print the Boruta token request and response with sensitive values redacted")
    parser.add_argument("--state-file", type=Path, default=DEFAULT_STATE_FILE, help="File used by --chain-session to store the full chained authorization code")
    parser.add_argument("--chain-session", action="store_true", help="Read the previous authorization code from --state-file and write the returned code back")
    parser.add_argument("--reset-chain", action="store_true", help="With --chain-session, ignore the stored previous code for this exchange and replace it with the returned code")
    args = parser.parse_args()

    actor = parse_actor(args.actor)
    scope = args.scope.strip() if args.scope else None
    token = actor_id_token(actor, args.event_kind, args.user_prompt)
    if args.chain_session:
        previous_code = None if args.reset_chain else read_previous_code(args.state_file)
    else:
        previous_code = args.previous_code

    if args.dry_run:
        next_code = "<dry-run>"
    else:
        next_code = exchange_code(actor, token, previous_code, scope, args.show_request)
        if args.chain_session:
            write_next_code(args.state_file, actor, args.event_kind, next_code)

    print(json.dumps({
        "actor_type": actor.actor_type,
        "actor_id": actor.actor_id,
        "event_kind": args.event_kind,
        "grant_type": GRANT_TYPE,
        "scope": scope,
        "token_endpoint": TOKEN_TARGET,
        "previous_authorization_code": truncate(previous_code) if previous_code else None,
        "returned_authorization_code": truncate(next_code),
        "state_file": str(args.state_file) if args.chain_session else None,
        "private_key_path": str(actor.private_key_path),
        "public_jwk_path": str(actor.public_jwk_path),
        "id_token_claims": {
            "sub": actor.actor_id,
            "actor_type": actor.actor_type,
            "event": args.event_kind,
            **({"user_prompt": args.user_prompt} if args.user_prompt else {}),
        },
        "id_token_preview": truncate(token),
        "dry_run": args.dry_run,
    }, indent=2))


if __name__ == "__main__":
    main()
