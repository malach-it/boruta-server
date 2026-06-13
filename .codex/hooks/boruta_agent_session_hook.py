from __future__ import annotations

import json
import os
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen


DEFAULT_ACTOR_BY_EVENT = {
    "UserPromptSubmit": "user:codex-user",
    "PreToolUse": "assistant:codex",
    "PermissionRequest": "assistant:codex",
    "PostToolUse": "tool:codex-tool",
    "Stop": "assistant:codex",
}


BLOCKABLE_EVENTS = {"UserPromptSubmit", "PreToolUse", "PermissionRequest", "Stop"}
CONTEXT_EVENTS = {"UserPromptSubmit", "PreToolUse", "PostToolUse"}
SESSION_ID_KEYS = (
    "session_id",
    "conversation_id",
    "thread_id",
    "codex_thread_id",
)
SESSION_ID_ENV_KEYS = (
    "CODEX_THREAD_ID",
    "CODEX_SESSION_ID",
    "CODEX_CONVERSATION_ID",
)
USER_PROMPT_KEYS = (
    "prompt",
    "user_prompt",
    "message",
)
DEFAULT_ADMIN_SCOPE = "scopes:manage:all"
DEFAULT_OAUTH_BASE_URL = "http://localhost:8080"
DEFAULT_BROWSER_REDIRECT_URI = "http://127.0.0.1:8765/oauth-callback"
DEFAULT_DOCKER_COMPOSE_COMMAND = "docker compose up -d"
DEFAULT_DOCKER_COMPOSE_TIMEOUT_SECONDS = 300


def normalize(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return re.sub(r"-+", "-", value).strip("-") or "unknown"


def repo_root(hook_input: dict[str, Any]) -> Path:
    cwd = Path(hook_input.get("cwd") or os.getcwd()).resolve()
    result = subprocess.run(
        ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip()).resolve()
    return Path(__file__).resolve().parents[2]


def event_kind(hook_input: dict[str, Any]) -> str:
    event = str(hook_input.get("hook_event_name") or "codex_hook")
    tool_name = hook_input.get("tool_name")
    source = hook_input.get("source")
    suffix = normalize(str(tool_name or source or ""))
    if suffix and suffix != "unknown":
        return f"codex_{normalize(event)}_{suffix}"
    return f"codex_{normalize(event)}"


def actor_for(hook_input: dict[str, Any]) -> str:
    event = str(hook_input.get("hook_event_name") or "")
    event_env = f"BORUTA_CODEX_HOOK_ACTOR_{event}"
    if os.getenv(event_env):
        return os.environ[event_env]

    if event == "PostToolUse":
        tool_name = normalize(str(hook_input.get("tool_name") or "codex-tool"))
        return f"tool:{tool_name}"

    return os.getenv("BORUTA_CODEX_HOOK_ACTOR", DEFAULT_ACTOR_BY_EVENT.get(event, "assistant:codex"))


def user_prompt_for(hook_input: dict[str, Any]) -> str | None:
    if hook_input.get("hook_event_name") != "UserPromptSubmit":
        return None

    for key in USER_PROMPT_KEYS:
        value = hook_input.get(key)
        if isinstance(value, str) and value:
            return value

    return None


def scope_for(hook_input: dict[str, Any]) -> str | None:
    scope = os.getenv("BORUTA_CODEX_HOOK_SCOPE")
    if scope and scope.strip():
        return scope.strip()

    event = hook_input.get("hook_event_name")
    scopes: list[str] = []
    if isinstance(event, str) and event:
        scopes.append(f"codex:event:{normalize(event)}")

    tool_name = normalize(str(hook_input.get("tool_name") or ""))
    if tool_name and tool_name != "unknown":
        scopes.append(f"codex:tool:{tool_name}")

    if event == "UserPromptSubmit":
        scopes.append("codex:prompt:submit")
    elif event == "PermissionRequest":
        scopes.append("codex:permission:request")
    elif event == "PostToolUse":
        scopes.append("codex:tool:result")
    elif event == "Stop":
        scopes.append("codex:session:stop")
    elif event == "PreToolUse":
        scopes.extend(pre_tool_use_scopes(hook_input, tool_name))

    return " ".join(dict.fromkeys(scopes)) or None


def pre_tool_use_scopes(hook_input: dict[str, Any], tool_name: str) -> list[str]:
    payload = hook_payload(hook_input)
    scopes = ["codex:tool:use"]

    if payload.get("sandbox_permissions") == "require_escalated":
        scopes.append("codex:permission:escalated")

    if "apply-patch" in tool_name:
        scopes.append("codex:file:patch")
    elif "imagegen" in tool_name:
        scopes.append("codex:image:generate")
    elif "write-stdin" in tool_name:
        scopes.append("codex:process:stdin")
    elif "exec-command" in tool_name or tool_name in {"bash", "shell"}:
        command = command_text(hook_input)
        scopes.append("codex:command:read" if read_only_command(command) else "codex:command:write")
    elif sensitive_tool_use(hook_input):
        scopes.append("codex:tool:sensitive")
    else:
        scopes.append("codex:tool:read")

    return scopes


def scope_names(scope: str | None) -> list[str]:
    if not scope:
        return []
    return list(dict.fromkeys(part for part in scope.split() if part))


def enabled(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() not in {"", "0", "false", "no", "off"}


def state_file_path() -> str | None:
    state_file = os.getenv("BORUTA_CODEX_HOOK_STATE_FILE")
    return os.path.expanduser(state_file) if state_file else None


def effective_state_file_path(state_file: str | None) -> Path:
    if state_file:
        return Path(state_file)
    return Path(
        os.path.expanduser(
            os.getenv("BORUTA_AGENT_SESSION_STATE_FILE", "~/.boruta/session-code-chain.json")
        )
    )


def session_marker_path(state_file: str | None) -> Path:
    marker_file = os.getenv("BORUTA_CODEX_HOOK_SESSION_FILE")
    if marker_file:
        return Path(os.path.expanduser(marker_file))
    if state_file:
        return Path(state_file).with_name("codex-hook-session.json")
    return Path(os.path.expanduser("~/.boruta/codex-hook-session.json"))


def scope_marker_path(state_file: str | None) -> Path:
    marker_file = os.getenv("BORUTA_CODEX_HOOK_SCOPE_SESSION_FILE")
    if marker_file:
        return Path(os.path.expanduser(marker_file))
    return session_marker_path(state_file).with_name("codex-hook-scopes-session.json")


def docker_compose_marker_path(state_file: str | None) -> Path:
    marker_file = os.getenv("BORUTA_CODEX_HOOK_DOCKER_COMPOSE_SESSION_FILE")
    if marker_file:
        return Path(os.path.expanduser(marker_file))
    return session_marker_path(state_file).with_name("codex-hook-docker-compose-session.json")


def session_id_for(hook_input: dict[str, Any], root: Path) -> str:
    for key in SESSION_ID_KEYS:
        value = hook_input.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()

    for key in SESSION_ID_ENV_KEYS:
        value = os.getenv(key)
        if value:
            return value

    return f"{root}:{os.getppid()}"


def read_session_marker(path: Path) -> str | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    session_id = payload.get("session_id")
    return session_id if isinstance(session_id, str) and session_id else None


def write_session_marker(path: Path, session_id: str, root: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump({
                "session_id": session_id,
                "repo_root": str(root),
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


def docker_compose_command() -> list[str]:
    command = os.getenv("BORUTA_CODEX_HOOK_DOCKER_COMPOSE_COMMAND", DEFAULT_DOCKER_COMPOSE_COMMAND)
    return shlex.split(command)


def docker_compose_timeout() -> float:
    return float(os.getenv(
        "BORUTA_CODEX_HOOK_DOCKER_COMPOSE_TIMEOUT",
        str(DEFAULT_DOCKER_COMPOSE_TIMEOUT_SECONDS),
    ))


def docker_compose_startup(hook_input: dict[str, Any], root: Path, state_file: str | None) -> str | None:
    if hook_input.get("hook_event_name") != "UserPromptSubmit":
        return None
    if not enabled("BORUTA_CODEX_HOOK_DOCKER_COMPOSE_START", default=True):
        return None

    marker_path = docker_compose_marker_path(state_file)
    session_id = session_id_for(hook_input, root)
    if read_session_marker(marker_path) == session_id:
        return None

    command = docker_compose_command()
    if not command:
        return "Docker Compose startup skipped: empty command"

    try:
        result = subprocess.run(
            command,
            cwd=str(root),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=docker_compose_timeout(),
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return f"Docker Compose startup failed: {type(error).__name__}: {error}"

    if result.returncode != 0:
        output = (result.stderr.strip() or result.stdout.strip() or "no output").splitlines()[-1]
        return f"Docker Compose startup failed: {' '.join(command)}: {output}"

    write_session_marker(marker_path, session_id, root)
    return None


def read_scope_marker(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def write_scope_marker(path: Path, session_id: str, root: Path, scopes: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump({
                "session_id": session_id,
                "repo_root": str(root),
                "scopes": scopes,
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


def truncate(value: str) -> str:
    if len(value) <= 18:
        return value
    return f"{value[:8]}...{value[-8:]}"


def oauth_base_url() -> str:
    return (
        os.getenv("BORUTA_CODEX_HOOK_OAUTH_BASE_URL")
        or os.getenv("BORUTA_OAUTH_BASE_URL")
        or DEFAULT_OAUTH_BASE_URL
    ).rstrip("/")


def browser_client_id() -> str:
    return os.getenv(
        "BORUTA_CODEX_HOOK_BROWSER_CLIENT_ID",
        os.getenv("BORUTA_AGENT_CHAT_CLIENT_ID", "00000000-0000-0000-0000-000000000001"),
    )


def browser_redirect_uri() -> str:
    return os.getenv(
        "BORUTA_CODEX_HOOK_BROWSER_REDIRECT_URI",
        os.getenv("BORUTA_AGENT_CHAT_REDIRECT_URI", DEFAULT_BROWSER_REDIRECT_URI),
    )


def browser_callback_host() -> str | None:
    return os.getenv("BORUTA_CODEX_HOOK_BROWSER_CALLBACK_HOST") or os.getenv("BORUTA_AGENT_CHAT_CALLBACK_HOST")


def browser_timeout() -> float:
    return float(os.getenv("BORUTA_CODEX_HOOK_BROWSER_TIMEOUT", "300"))


def read_previous_authorization_code(state_file: Path) -> str | None:
    try:
        payload = json.loads(state_file.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    code = payload.get("authorization_code")
    return code if isinstance(code, str) and code else None


def write_browser_authorization_code(
    state_file: Path,
    hook_input: dict[str, Any],
    scope: str | None,
    authorization_code: str,
) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{state_file.name}.", dir=str(state_file.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump({
                "authorization_code": authorization_code,
                "authorization_code_preview": truncate(authorization_code),
                "actor": actor_for(hook_input),
                "event_kind": event_kind(hook_input),
                "scope": scope,
                "grant_type": "authorization_code",
                "token_endpoint": f"{oauth_base_url()}/oauth/token",
                "updated_at": int(time.time()),
            }, tmp, indent=2)
            tmp.write("\n")
            tmp.flush()
            os.fsync(tmp.fileno())
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, state_file)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def reset_authorization_state(state_file: Path) -> None:
    try:
        state_file.unlink()
    except FileNotFoundError:
        return


def reset_state_on_user_prompt(hook_input: dict[str, Any], state_file: Path) -> None:
    if hook_input.get("hook_event_name") != "UserPromptSubmit":
        return
    if not enabled("BORUTA_CODEX_HOOK_RESET_ON_USER_PROMPT", default=True):
        return
    reset_authorization_state(state_file)


class BrowserCallback:
    def __init__(self) -> None:
        self.condition = threading.Condition()
        self.code: str | None = None
        self.error: str | None = None

    def wait(self, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        with self.condition:
            while self.code is None and self.error is None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                self.condition.wait(remaining)
            if self.code:
                return self.code
            if self.error:
                raise RuntimeError(self.error)
        raise TimeoutError("timed out waiting for browser authorization callback")

    def set_code(self, code: str) -> None:
        with self.condition:
            self.code = code
            self.condition.notify_all()

    def set_error(self, error: str) -> None:
        with self.condition:
            self.error = error
            self.condition.notify_all()


def browser_callback_server(redirect_uri: str, callback: BrowserCallback, expected_state: str) -> HTTPServer:
    parsed = urlparse(redirect_uri)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or not parsed.port:
        raise RuntimeError("browser redirect URI must include an http host and explicit port")

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            query = parse_qs(urlparse(self.path).query)
            state = first_query_value(query, "state")
            code = first_query_value(query, "code")
            error = first_query_value(query, "error_description") or first_query_value(query, "error")

            if state != expected_state:
                callback.set_error("authorization callback state mismatch")
                self.respond_html("Authorization callback state mismatch.", status=400)
                return

            if code:
                callback.set_code(code)
                self.respond_html("Authorization code received. You can close this tab.")
                return

            if error:
                callback.set_error(error)
                self.respond_html(f"Authorization failed: {error}", status=400)
                return

            self.respond_html("Authorization callback did not include a code.", status=400)

        def log_message(self, _format: str, *_args: object) -> None:
            return

        def respond_html(self, body: str, status: int = 200) -> None:
            content = (
                "<!doctype html><meta charset='utf-8'>"
                f"<title>Boruta Codex authorization</title><p>{body}</p>"
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("content-type", "text/html; charset=utf-8")
            self.send_header("content-length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

    return HTTPServer((browser_callback_host() or parsed.hostname, parsed.port), CallbackHandler)


def first_query_value(values: dict[str, list[str]], key: str) -> str | None:
    value = values.get(key)
    return value[0] if value else None


def browser_authorization_status(
    hook_input: dict[str, Any],
    scope: str | None,
    previous_code: str | None,
    returned_code: str,
    opened_browser: bool,
) -> str:
    rows = [
        ("status", "authorized"),
        ("actor", actor_for(hook_input)),
        ("event", event_kind(hook_input)),
        ("scope", scope or "none"),
        ("grant", "authorization_code"),
        ("browser", "opened" if opened_browser else "manual"),
        ("previous", truncate(previous_code) if previous_code else "none"),
        ("returned", truncate(returned_code)),
    ]
    label_width = max(len(label) for label, _value in rows)
    body = "\n".join(f"  {label.rjust(label_width)} : {value}" for label, value in rows)
    return f"Boruta authorization\n{body}"


def browser_authorization_code(
    hook_input: dict[str, Any],
    scope: str | None,
    state_file: Path,
    reset_chain: bool,
) -> str:
    redirect_uri = browser_redirect_uri()
    previous_code = None if reset_chain else read_previous_authorization_code(state_file)
    callback = BrowserCallback()
    state = secrets.token_urlsafe(32)
    server = browser_callback_server(redirect_uri, callback, state)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    params = {
        "client_id": browser_client_id(),
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "state": state,
    }
    if scope:
        params["scope"] = scope
    if previous_code:
        params["code"] = previous_code
    authorize_url = f"{oauth_base_url()}/oauth/authorize?{urlencode(params)}"
    opened_browser = enabled("BORUTA_CODEX_HOOK_OPEN_BROWSER", default=True)

    try:
        if opened_browser:
            webbrowser.open(authorize_url)
        code = callback.wait(browser_timeout())
        write_browser_authorization_code(state_file, hook_input, scope, code)
        return browser_authorization_status(hook_input, scope, previous_code, code, opened_browser)
    finally:
        server.shutdown()
        server.server_close()


def should_reset_chain(hook_input: dict[str, Any], root: Path, marker_path: Path) -> tuple[bool, str | None]:
    if enabled("BORUTA_CODEX_HOOK_RESET_CHAIN"):
        return True, None

    if hook_input.get("hook_event_name") != "UserPromptSubmit":
        return False, None

    if enabled("BORUTA_CODEX_HOOK_RESET_ON_USER_PROMPT", default=True):
        return True, None

    if not enabled("BORUTA_CODEX_HOOK_RESET_ON_SESSION_START"):
        return False, None

    session_id = session_id_for(hook_input, root)
    return read_session_marker(marker_path) != session_id, session_id


def parse_json_stream(output: str) -> list[Any]:
    decoder = json.JSONDecoder()
    values: list[Any] = []
    index = 0
    while index < len(output):
        while index < len(output) and output[index].isspace():
            index += 1
        if index >= len(output):
            break
        value, index = decoder.raw_decode(output, index)
        values.append(value)
    return values


def authorizer_result(output: str) -> dict[str, Any] | None:
    try:
        values = parse_json_stream(output)
    except json.JSONDecodeError:
        return None

    for value in reversed(values):
        if isinstance(value, dict) and "returned_authorization_code" in value:
            return value
    return None


def authorization_status_fields(result: dict[str, Any], reset_chain: bool) -> dict[str, str]:
    chain = "reset" if reset_chain else "chained"
    if result.get("dry_run"):
        chain = f"{chain}, dry-run"
    return {
        "actor": str(result.get("actor_id") or result.get("actor_type") or "unknown"),
        "event": str(result.get("event_kind") or "unknown"),
        "grant": str(result.get("grant_type") or "code_chain"),
        "scope": str(result.get("scope") or "none"),
        "chain": chain,
        "previous": str(result.get("previous_authorization_code") or "none"),
        "returned": str(result.get("returned_authorization_code") or "none"),
    }


def authorization_status_line(result: dict[str, Any], reset_chain: bool) -> str:
    fields = authorization_status_fields(result, reset_chain)
    return (
        "Boruta authorization accepted: "
        f"actor={fields['actor']} event={fields['event']} grant={fields['grant']} chain={fields['chain']} "
        f"scope={fields['scope']} previous={fields['previous']} returned={fields['returned']}"
    )


def authorization_status_panel(result: dict[str, Any], reset_chain: bool) -> str:
    fields = authorization_status_fields(result, reset_chain)
    rows = [
        ("status", "authorized"),
        ("actor", fields["actor"]),
        ("event", fields["event"]),
        ("grant", fields["grant"]),
        ("scope", fields["scope"]),
        ("chain", fields["chain"]),
        ("previous", fields["previous"]),
        ("returned", fields["returned"]),
    ]
    label_width = max(len(label) for label, _value in rows)
    body = "\n".join(f"  {label.rjust(label_width)} : {value}" for label, value in rows)
    return f"Boruta authorization\n{body}"


def authorization_status(result: dict[str, Any], reset_chain: bool) -> str:
    style = os.getenv("BORUTA_CODEX_HOOK_STATUS_STYLE", "panel").strip().lower()
    if style == "line":
        return authorization_status_line(result, reset_chain)
    return authorization_status_panel(result, reset_chain)


def parse_authorizer_error(output: str) -> dict[str, str]:
    details: dict[str, str] = {}
    status_match = re.search(r"token call failed: status=(\d+)", output)
    if status_match:
        details["status"] = status_match.group(1)

    body_matches = re.findall(r"body=({[^\n]*})", output)
    for body_text in reversed(body_matches):
        try:
            body = json.loads(body_text)
            if isinstance(body.get("error"), str):
                details["error"] = body["error"]
            if isinstance(body.get("error_description"), str):
                details["description"] = body["error_description"]
            break
        except json.JSONDecodeError:
            if "description" not in details:
                details["description"] = body_text

    if not details:
        lines = [line.strip() for line in output.splitlines() if line.strip()]
        if lines:
            details["description"] = lines[-1]

    return details


def authorization_failure_status(
    hook_input: dict[str, Any],
    scope: str | None,
    output: str,
) -> str:
    fields = {
        "actor": actor_for(hook_input),
        "event": event_kind(hook_input),
        "scope": scope or "none",
        **parse_authorizer_error(output),
    }
    rows = [
        ("status", "failed"),
        ("actor", fields["actor"]),
        ("event", fields["event"]),
        ("scope", fields["scope"]),
        ("http", fields.get("status", "unknown")),
        ("error", fields.get("error", "authorization_failed")),
        ("detail", fields.get("description", "Boruta authorization failed")),
    ]
    label_width = max(len(label) for label, _value in rows)
    body = "\n".join(f"  {label.rjust(label_width)} : {value}" for label, value in rows)
    return f"Boruta authorization\n{body}"


def hook_payload(hook_input: dict[str, Any]) -> dict[str, Any]:
    for key in ("tool_input", "tool_args", "parameters", "input"):
        value = hook_input.get(key)
        if isinstance(value, dict):
            return value
    return {}


def command_text(hook_input: dict[str, Any]) -> str:
    payload = hook_payload(hook_input)
    for key in ("cmd", "command"):
        value = payload.get(key)
        if isinstance(value, str):
            return value.strip()
    return ""


def read_only_command(command: str) -> bool:
    if not command:
        return False

    first_segment = re.split(r"\s*(?:&&|\|\||;|\|)\s*", command, maxsplit=1)[0].strip()
    parts = first_segment.split()
    if not parts:
        return False

    read_only_commands = {
        "cat",
        "date",
        "find",
        "head",
        "ls",
        "nl",
        "pwd",
        "rg",
        "sed",
        "tail",
        "tree",
        "wc",
    }
    mutating_git_commands = {
        "add",
        "am",
        "apply",
        "checkout",
        "cherry-pick",
        "clean",
        "commit",
        "merge",
        "mv",
        "pull",
        "push",
        "rebase",
        "reset",
        "restore",
        "revert",
        "rm",
        "switch",
    }

    if parts[0] == "git" and len(parts) > 1:
        return parts[1] not in mutating_git_commands

    return parts[0] in read_only_commands


def sensitive_tool_use(hook_input: dict[str, Any]) -> bool:
    tool_name = normalize(str(hook_input.get("tool_name") or ""))

    if "apply-patch" in tool_name or "imagegen" in tool_name or "write-stdin" in tool_name:
        return True

    if "exec-command" in tool_name or tool_name in {"bash", "shell"}:
        payload = hook_payload(hook_input)
        if payload.get("sandbox_permissions") == "require_escalated":
            return True
        return not read_only_command(command_text(hook_input))

    return False


def should_authorize_hook(hook_input: dict[str, Any]) -> bool:
    if enabled("BORUTA_CODEX_HOOK_AUTHORIZE_ALL", default=True):
        return True

    event = hook_input.get("hook_event_name")
    if event == "PermissionRequest":
        return True
    if event == "PreToolUse":
        return sensitive_tool_use(hook_input)
    return False


def should_use_browser_authorization(hook_input: dict[str, Any]) -> bool:
    if not enabled("BORUTA_CODEX_HOOK_BROWSER_AUTH", default=True):
        return False

    if enabled("BORUTA_CODEX_HOOK_BROWSER_AUTH_FOR_ALL"):
        return True

    event = hook_input.get("hook_event_name")
    if event == "PermissionRequest":
        return True
    if event == "PreToolUse":
        return sensitive_tool_use(hook_input)
    return False


def codex_output(
    hook_input: dict[str, Any],
    message: str | None = None,
    block: bool = False,
    include_context: bool = True,
) -> dict[str, Any]:
    event = str(hook_input.get("hook_event_name") or "")
    output: dict[str, Any] = {}

    if message:
        output["systemMessage"] = message

    if block and event in BLOCKABLE_EVENTS:
        output["decision"] = "block"
        output["reason"] = message or "Boruta authorization failed"

    if include_context and message and event in CONTEXT_EVENTS:
        output["hookSpecificOutput"] = {
            "hookEventName": event,
            "additionalContext": message,
        }

    return output


def main() -> int:
    raw_input = sys.stdin.read()
    try:
        hook_input = json.loads(raw_input or "{}")
    except json.JSONDecodeError as error:
        print(json.dumps({"systemMessage": f"Boruta hook ignored invalid JSON input: {error}"}))
        return 0

    state_file = state_file_path()
    reset_state_on_user_prompt(hook_input, effective_state_file_path(state_file))

    if not should_authorize_hook(hook_input):
        return 0

    root = repo_root(hook_input)
    startup_error = docker_compose_startup(hook_input, root, state_file)
    if startup_error:
        print(json.dumps(codex_output(hook_input, startup_error)))
        return 0

    authorizer = root / "scripts" / "agent_session_authorize.py"
    if not authorizer.is_file():
        print(json.dumps(codex_output(hook_input, f"Boruta authorizer not found: {authorizer}")))
        return 0

    command = [
        sys.executable,
        str(authorizer),
        "--actor",
        actor_for(hook_input),
        "--event-kind",
        event_kind(hook_input),
        "--chain-session",
    ]

    user_prompt = user_prompt_for(hook_input)
    if user_prompt:
        command.extend(["--user-prompt", user_prompt])

    scope = scope_for(hook_input)
    if scope:
        command.extend(["--scope", scope])

    if state_file:
        command.extend(["--state-file", state_file])

    if enabled("BORUTA_CODEX_HOOK_SHOW_REQUEST"):
        command.append("--show-request")

    marker_path = session_marker_path(state_file)
    reset_chain, reset_session_id = should_reset_chain(hook_input, root, marker_path)
    if reset_chain:
        command.append("--reset-chain")

    if should_use_browser_authorization(hook_input):
        failed = False
        try:
            message = browser_authorization_code(
                hook_input,
                scope,
                effective_state_file_path(state_file),
                reset_chain,
            )
        except Exception as error:
            failed = True
            message = authorization_failure_status(hook_input, scope, f"{type(error).__name__}: {error}")
        enforce = enabled("BORUTA_CODEX_HOOK_ENFORCE", default=True)
        print(json.dumps(codex_output(
            hook_input,
            message,
            block=failed and enforce,
            include_context=enabled("BORUTA_CODEX_HOOK_STATUS_CONTEXT"),
        )))
        return 0

    if enabled("BORUTA_CODEX_HOOK_DRY_RUN", default=False):
        command.append("--dry-run")

    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    if result.returncode == 0:
        if reset_session_id:
            write_session_marker(marker_path, reset_session_id, root)
        if enabled("BORUTA_CODEX_HOOK_VERBOSE"):
            print(json.dumps(codex_output(hook_input, result.stdout.strip())))
        elif enabled("BORUTA_CODEX_HOOK_STATUS", default=True):
            parsed_result = authorizer_result(result.stdout)
            message = authorization_status(parsed_result, reset_chain) if parsed_result else "Boruta authorization accepted"
            print(json.dumps(codex_output(
                hook_input,
                message,
                include_context=enabled("BORUTA_CODEX_HOOK_STATUS_CONTEXT"),
            )))
        return 0

    authorizer_output = result.stderr.strip() or result.stdout.strip()
    message = authorization_failure_status(hook_input, scope, authorizer_output)

    enforce = enabled("BORUTA_CODEX_HOOK_ENFORCE", default=True)
    print(json.dumps(codex_output(hook_input, message, block=enforce)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
