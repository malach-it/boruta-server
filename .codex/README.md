# Boruta Codex Hook Example

This directory contains a local Codex hook example that authorizes Codex events
through Boruta. Note that it is a Proof of Concept and not aimed for production
yet.

## Introduction

The hook lets a Codex session participate in Boruta's authorization model
before important work is performed. Codex invokes it for configured lifecycle
events such as user prompts, tool calls, permission requests, tool results, and
turn stops. For each event, the hook identifies an actor, derives an event kind
and scopes from the Codex payload, and asks Boruta for a chained authorization
code through `scripts/agent_session_authorize.py`.

Sensitive events can be routed through a browser authorization flow so a local
operator explicitly approves the action. When enforcement is enabled, failed
authorization blocks blockable Codex events; otherwise the hook only reports
authorization status back to Codex. The hook can also start the local Boruta
Docker Compose stack once per Codex session before the first authorization
attempt.

## Files

- `hooks/boruta_agent_session_hook.py`: hook command invoked by Codex.
- `config.example.toml`: sanitized Codex hook configuration template.
- `boruta-hook.env.example`: sanitized environment template for Boruta/OAuth
  settings.
- `config.toml`: local machine config, intentionally ignored by git.

## Setup

1. Copy `.codex/config.example.toml` to `.codex/config.toml`.
2. Replace `/absolute/path/to/boruta-server` with this checkout path.
3. Export the variables from `.codex/boruta-hook.env.example` with local
values.
4. Ensure Boruta is running at `BORUTA_OAUTH_BASE_URL`, or keep
`BORUTA_CODEX_HOOK_DOCKER_COMPOSE_START=true` to let the hook run Docker
Compose once per Codex session.

The hook writes session state and generated actor keys under `~/.boruta` by
default. Those files are sensitive and should stay outside the repository.

## Boruta Configuration Note

The Codex scopes must be configured in Boruta before the hook can authorize
events. The seed file creates the Codex scopes and a codex role containing
them.

Make sure the OAuth client used by the hook is allowed to request those scopes.
For browser-based authorization, the authorizing user or backend identity must
also have those scopes, typically through the seeded codex role.

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

~/.boruta/codex-hook-session.json ~/.boruta/codex-hook-scopes-session.json
~/.boruta/codex-hook-docker-compose-session.json

These track the current Codex session, browser-authorized scopes, and whether
Docker Compose startup has already run.

## Permissions

The hook maps Codex events and tools to Boruta scopes. Each event includes a
normalized event scope, then adds more specific scopes.

Examples:

UserPromptSubmit  -> codex:prompt:submit PermissionRequest ->
codex:permission:request PostToolUse       -> codex:tool:result Stop
-> codex:session:stop

Tool calls add:

codex:tool:use

plus a tool-specific scope:

apply_patch      -> codex:file:patch image generation -> codex:image:generate
write_stdin      -> codex:process:stdin read command     -> codex:command:read
write command    -> codex:command:write

If a request asks for escalated sandbox permissions, the hook also requires:

codex:permission:escalated

Actor keys are stored separately under:

~/.boruta/keys

with these permissions:

~/.boruta/keys   0700 private keys     0600 public JWKs      0644

If a private key is too open, the authorizer rejects it.

When enforcement is enabled:

BORUTA_CODEX_HOOK_ENFORCE=true

Boruta authorization failures block the Codex action. When disabled, failures
are reported but Codex continues.
