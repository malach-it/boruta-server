# Boruta Codex Hook Example

This directory contains a local Codex hook example that authorizes Codex events
through Boruta. Note that it is a Proof of Concept and not aimed for production
yet.

## Introduction

The hook lets a Codex session participate in Boruta's authorization model
before important work is performed. Codex invokes it for configured lifecycle
events such as session start, user prompts, tool calls, permission requests,
tool results, and turn stops. For each authorized event, the hook identifies an
actor, derives an event kind and scopes from the Codex payload, and asks Boruta
for a chained authorization code through `scripts/agent_session_authorize.py`.

Sensitive events can be routed through a browser authorization flow so a local
operator explicitly approves the action. When enforcement is enabled, failed
authorization blocks blockable Codex events; otherwise the hook only reports
authorization status back to Codex. The hook can also start the local Boruta
Docker Compose stack once per Codex session before the first authorization
attempt.

## Files

- `hooks/boruta_session_start_hook.py`: SessionStart bootstrap hook.
- `hooks/boruta_agent_session_hook.py`: authorization hook for prompt/tool/stop events.
- `hooks/boruta_wallet_hook.py`: local wallet responder and request-JWT verification.
- `config.example.toml`: sanitized Codex hook configuration template.
- `boruta-hook.env.example`: sanitized environment template for Boruta/OAuth
  settings.
- `config.toml`: local machine config, intentionally ignored by git.
- `boruta-hook.env`: local machine environment, intentionally ignored by git.

## Setup

1. Copy `.codex/config.example.toml` to `.codex/config.toml`.
2. Replace `/absolute/path/to/boruta-server` with this checkout path.
3. Copy `.codex/boruta-hook.env.example` to `.codex/boruta-hook.env` and fill
   in local values. The example hook configuration loads this file before
   running the hook.
4. Ensure Boruta is running at `BORUTA_OAUTH_BASE_URL`, or keep
   `BORUTA_CODEX_HOOK_DOCKER_COMPOSE_START=true` to let the hook run Docker
   Compose once per Codex session.

The hook writes session state and generated actor keys under `~/.boruta` by
default. Those files are sensitive and should stay outside the repository.
It also stores each hook input as an actor-signed JWT credential under
`~/.boruta/agent_credentials` by default.
Actor `id_token`s include `agent_wallet_url` and
`hook_presentation_definition` claims. The presentation definition field
constraints select the stored hook-input credential by its random
`credential_filename`.

## Local Environment

The environment file contains the OAuth endpoints, client credentials, state
paths, and hook behavior flags. At minimum, review these values:

```sh
BORUTA_OAUTH_BASE_URL=http://localhost:8080
BORUTA_CODEX_HOOK_CLIENT_ID=00000000-0000-0000-0000-000000000001
BORUTA_CODEX_HOOK_CLIENT_SECRET=replace-with-client-secret
BORUTA_CODEX_HOOK_TOKEN_TARGET=http://localhost:8080/oauth/token
BORUTA_CODEX_HOOK_KEYS_DIR=~/.boruta/keys
BORUTA_AGENT_SESSION_STATE_FILE=~/.boruta/session-code-chain.json
BORUTA_AGENT_CREDENTIALS_DIR=~/.boruta/agent_credentials
```

The hook can also use an interactive browser authorization flow:

```sh
BORUTA_CODEX_HOOK_BROWSER_CLIENT_ID=00000000-0000-0000-0000-000000000001
BORUTA_CODEX_HOOK_BROWSER_REDIRECT_URI=http://127.0.0.1:8765/oauth-callback
BORUTA_CODEX_HOOK_BROWSER_CALLBACK_HOST=127.0.0.1
BORUTA_CODEX_HOOK_BROWSER_TIMEOUT=300
BORUTA_CODEX_HOOK_OPEN_BROWSER=true
BORUTA_CODEX_HOOK_VERIFIABLE_PRESENTATION_URL=http://localhost:8080/oauth/authorize
```

`BORUTA_CODEX_HOOK_BROWSER_AUTH=false` disables browser authorization. When it
is enabled, browser authorization is used for `PermissionRequest` events and
sensitive `PreToolUse` events by default. Set
`BORUTA_CODEX_HOOK_BROWSER_AUTH_FOR_ALL=true` to route every authorized event
through the browser.

By default the hook authorizes every configured event except `SessionStart` and
`Stop`. `SessionStart` only bootstraps local services, and `Stop` only runs
shutdown cleanup.

```sh
BORUTA_CODEX_HOOK_AUTHORIZE_ALL=true
```

Set it to `false` to authorize only `PermissionRequest` events and sensitive
`PreToolUse` events. `Stop` events are never authorized.

## Boruta Configuration Note

The Codex scopes must be configured in Boruta before the hook can authorize
events. The seed file creates the Codex scopes and a codex role containing
them.

Make sure the OAuth client used by the hook is allowed to request those scopes.
For browser-based authorization, the authorizing user or backend identity must
also have those scopes, typically through the seeded `Codex agent` role.

If either side is missing the scope, Boruta rejects the hook request as an
unknown or unauthorized scope.

## Hook Sessions

Each Codex hook event is authorized through Boruta as part of a chained
session. The hook stores the latest returned authorization code in:

~/.boruta/session-code-chain.json

That file defaults to mode 0600, and its parent directory is forced to mode
0700. The path can be changed with:

BORUTA_AGENT_SESSION_STATE_FILE

On the next hook event, the stored code is sent back to Boruta as the previous
code. This creates a continuous authorization chain across the Codex workflow:
user prompt, tool calls, permission requests, tool results, and session stop
events.

By default, a new user prompt starts a fresh chain:

BORUTA_CODEX_HOOK_RESET_ON_USER_PROMPT=true

For one chain per Codex session instead:

BORUTA_CODEX_HOOK_RESET_ON_USER_PROMPT=false
BORUTA_CODEX_HOOK_RESET_ON_SESSION_START=true

The hook also writes session marker files, all mode 0600 by default:

```text
~/.boruta/codex-hook-session.json
~/.boruta/codex-hook-scopes-session.json
~/.boruta/codex-hook-docker-compose-session.json
~/.boruta/codex-hook-wallet-server-session.json
```

These track the current Codex session, browser-authorized scopes, and whether
Docker Compose startup has already run. The wallet marker additionally records
the hook-managed wallet server PID when enabled. If the wallet server crashes,
later non-Stop hook events restart it when this marker belongs to the current
Codex session.

## Docker Compose Startup

On `SessionStart`, `hooks/boruta_session_start_hook.py` starts the local
Boruta stack once per Codex session unless startup is disabled. The main
authorization hook falls back to `UserPromptSubmit` startup if needed:

```sh
BORUTA_CODEX_HOOK_DOCKER_COMPOSE_START=true
BORUTA_CODEX_HOOK_DOCKER_COMPOSE_COMMAND="docker compose up -d"
BORUTA_CODEX_HOOK_DOCKER_COMPOSE_TIMEOUT=300
```

Startup failures are reported to Codex as status messages and do not block the
session by themselves.

## Wallet Server

The hook can also run a local wallet responder for the full Codex session. The
wallet implementation lives in `hooks/boruta_wallet_hook.py`. When enabled, it
starts on `SessionStart`, falls back to starting on
`UserPromptSubmit` if needed, records its PID under `~/.boruta`, and stops that
process on `Stop`:

```sh
BORUTA_CODEX_HOOK_WALLET_SERVER=true
BORUTA_CODEX_HOOK_WALLET_SERVER_URL=http://127.0.0.1:8766/agent/wallet
BORUTA_CODEX_HOOK_WALLET_ACTOR=user:codex-wallet
```

The hook starts the child responder by invoking the wallet module with
`BORUTA_CODEX_HOOK_SERVE_WALLET_SERVER=true`; no wallet-server CLI flag is
required.

`SessionStart` is treated as a bootstrap-only event: it can start Docker
Compose and the wallet server, but it does not run the Boruta authorization
chain. This avoids a startup loop where authorization needs local services
before the hook has had a chance to start them.

During browser authorization, the callback server forwards Boruta wallet
deeplinks containing a `request` parameter to that local wallet server. The
wallet server posts an `id_token` to the deeplink `redirect_uri` by default.
For `vp_token` requests, it selects the stored credential named by the
`presentation_definition`, builds a verifiable presentation, and posts it to
the request `redirect_uri`. The POST reuses `BORUTA_CODEX_HOOK_CLIENT_ID` and
`BORUTA_CODEX_HOOK_CLIENT_SECRET` as `client_id` and `client_secret`.

## Permissions

The hook maps Codex events and tools to Boruta scopes. Each event includes a
normalized event scope, then adds more specific scopes.

Event scopes:

| Codex event | Added scopes |
| --- | --- |
| `SessionStart` | `codex:event:sessionstart`, `codex:session:start` |
| `UserPromptSubmit` | `codex:event:userpromptsubmit`, `codex:prompt:submit` |
| `PreToolUse` | `codex:event:pretooluse`, `codex:tool:use`, tool-specific scopes |
| `PermissionRequest` | `codex:event:permissionrequest`, `codex:permission:request` |
| `PostToolUse` | `codex:event:posttooluse`, `codex:tool:result` |
| `Stop` | not authorized; reserved for shutdown cleanup |

`PreToolUse` also adds a normalized tool scope when Codex provides a tool name,
for example `codex:tool:functions-exec-command`.

Tool-specific scopes:

| Tool or action | Added scope |
| --- | --- |
| `apply_patch` | `codex:file:patch` |
| image generation | `codex:image:generate` |
| `write_stdin` | `codex:process:stdin` |
| read-only command | `codex:command:read` |
| mutating command | `codex:command:write` |
| other sensitive tool | `codex:tool:sensitive` |
| other read-only tool | `codex:tool:read` |

If a request asks for escalated sandbox permissions, the hook also requires:

```text
codex:permission:escalated
```

Commands are treated as read-only only when the first command segment is one of
`cat`, `date`, `find`, `head`, `ls`, `nl`, `pwd`, `rg`, `sed`, `tail`, `tree`,
or `wc`. `git` commands are read-only unless the subcommand is mutating, such as
`add`, `commit`, `checkout`, `pull`, `push`, `rebase`, `reset`, or `rm`.

You can override the derived actor or scope with environment variables:

```sh
BORUTA_CODEX_HOOK_ACTOR=user:codex-user
BORUTA_CODEX_HOOK_ACTOR_UserPromptSubmit=user:codex-user
BORUTA_CODEX_HOOK_ACTOR_PreToolUse=assistant:codex
BORUTA_CODEX_HOOK_SCOPE="codex:event:userpromptsubmit codex:prompt:submit"
```

Without overrides, `PostToolUse` actors are derived from the tool name
(`tool:<normalized-tool-name>`), and other events use the defaults in the hook
script.

Actor keys are stored separately under:

```text
~/.boruta/keys
```

with these permissions:

```text
~/.boruta/keys  0700
private keys    0600
public JWKs     0644
```

If a private key is too open, the authorizer rejects it.

When enforcement is enabled:

BORUTA_CODEX_HOOK_ENFORCE=true

Boruta authorization failures block the Codex action. When disabled, failures
are reported but Codex continues.

Status output is enabled by default:

```sh
BORUTA_CODEX_HOOK_STATUS=true
BORUTA_CODEX_HOOK_STATUS_STYLE=panel
BORUTA_CODEX_HOOK_STATUS_CONTEXT=false
```

Set `BORUTA_CODEX_HOOK_STATUS_STYLE=line` for a single-line status message, or
`BORUTA_CODEX_HOOK_VERBOSE=true` to return the raw authorizer output.
