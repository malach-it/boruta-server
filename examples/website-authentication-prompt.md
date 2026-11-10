# Reusable website authentication setup prompt

Copy the following prompt and replace the bracketed values:

```text
Starting from an empty authentication installation, protect the website in
[WEBSITE_REPOSITORY] with the local Boruta Docker image [IMAGE:TAG]. Inspect the
existing site, local image, Boruta source and documentation before choosing a flow.
Preserve unrelated work and never print credentials.

Use boruta-cli as the primary provisioning interface. Inspect its actual commands
and validate support in the installed image. Discover generated IDs rather than
hard-coding them. Make provisioning repeatable, preserve existing passwords, and
keep revoked user permissions revoked on reruns. If a required operation is missing
or broken in this CLI, reproduce the limitation, explain it, and use the smallest
necessary fallback. Do not silently replace CLI provisioning with broad release RPC.

Use these URLs and access requirements:
- Website: [LOCAL_WEBSITE_ORIGIN]
- Browser-visible issuer: [ISSUER_ORIGIN]
- Administration: [ADMIN_ORIGIN]
- Private upstream: [DOCKER_SERVICE:PORT]
- Authentication: normal email-and-password login through Boruta’s identity provider
- Authorized audience: [INVITED_ACCOUNTS / ROLE]
- Environment: [LOCAL_ONLY / STAGING / PRODUCTION]

For a local setup, supply Docker Compose with the local Boruta image (no automatic
remote substitution), persistent PostgreSQL/log volumes, generated ignored secrets,
readiness checks, and no published upstream or database ports. Bind public-facing
local test ports to loopback. Keep browser-visible URLs separate from Docker DNS.
For staging/production, implement and verify the actual HTTPS topology and Secure
cookie behavior; do not claim that local HTTP validation proves production security.

Protect every website page and asset at the gateway. Configure an explicit browser
session flow supported by this exact image, the appropriate client/provider binding,
exact redirect allowlist, explicit grants and token lifetimes, and least-privilege
scope/role policy. Disable public registration for invited-only access. Do not treat
an open registration or a sample username credential as membership authorization.
Use the identity provider's normal email-and-password login form. Provision invited
accounts with the required private scope or role, preserve existing passwords on
reruns, and verify that accounts without that permission cannot access the website.
Enable the identity provider's choose-session page (`choose_session: true`) so users
can explicitly choose an existing session or sign in with another account. Preserve
this setting in repeatable provisioning.
Use the gateway's supported browser login flow and website callback rather than
wallet presentation. Do not configure wallet enrollment, membership credentials,
`vp_token` requests, or a wallet redirect URI for website authentication. Verify that
successful password login returns through the gateway callback to the requested
website path and query, and that protected website content loads afterward.

Include the necessary logout UI, prevent caching of private responses, and explain
whether logout ends only the gateway session or also the identity-provider session.
Document JavaScript-readable token cookies and any implicit-flow limitations.

Provide one startup command, repeatable CLI provisioning, and executable verification.
Test from an empty database and then repeat bootstrap. Check anonymous pages/assets
and HEAD requests, wrong credentials, valid login, callback state handling, original
path/query restoration, cache/cookie behavior, logout/token revocation, and replay
of the revoked session. Verify there is no direct upstream port bypass. Clearly
separate checks actually executed from any untested behavior.

Document the full steps, CLI examples, generated files, credential locations,
backup/reset semantics, troubleshooting, tested image digest, and any deployment
that remains outside this setup. Finish the authorized local implementation and
verification without stopping at a plan or deploying unrelated infrastructure.
```
