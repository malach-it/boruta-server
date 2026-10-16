#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

HOOKS_DIR = Path(__file__).resolve().parent
if str(HOOKS_DIR) not in sys.path:
    sys.path.insert(0, str(HOOKS_DIR))

import boruta_wallet_hook as wallet


def load_agent_hook():
    sys.dont_write_bytecode = True
    hook_path = Path(__file__).with_name("boruta_agent_session_hook.py")
    spec = importlib.util.spec_from_file_location("boruta_agent_session_hook", hook_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load hook module: {hook_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def codex_output(message: str | None = None) -> dict[str, Any]:
    return {"systemMessage": message} if message else {}


def main() -> int:
    raw_input = sys.stdin.read()
    try:
        hook_input = json.loads(raw_input or "{}")
    except json.JSONDecodeError as error:
        print(json.dumps(codex_output(f"Boruta SessionStart hook ignored invalid JSON input: {error}")))
        return 0

    hook = load_agent_hook()
    state_file = hook.state_file_path()
    root = hook.repo_root(hook_input)

    session_id = hook.session_id_for(hook_input, root)
    wallet_startup_error = wallet.start_session_wallet_server(hook_input, root, state_file, session_id)
    if wallet_startup_error:
        print(json.dumps(codex_output(wallet_startup_error)))
        return 0

    startup_error = hook.docker_compose_startup(hook_input, root, state_file)
    if startup_error:
        print(json.dumps(codex_output(startup_error)))
        return 0

    if hook.enabled("BORUTA_CODEX_HOOK_VERBOSE"):
        print(json.dumps(codex_output("Boruta SessionStart bootstrap complete.")))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
