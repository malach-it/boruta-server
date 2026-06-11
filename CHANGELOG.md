# Changelog

> Note that 0.X.X releases are reverved for the beta version of the server and may include breaking changes.

## [Unreleased]

### Added

- [gateway] HTTP and HTTPS forward proxies
- [gateway] HTTPS gateway and sidecar listeners
- [gateway] service registry root CA and node certificate generation
- [gateway] service registry records expose node gateway and proxy listener configuration
- [gateway] service registry records expose certificate paths and node certificates
- [gateway] gateway listeners can be configured with `BORUTA_GATEWAY_SERVER` and `BORUTA_GATEWAY_SIDECAR`
- [gateway] upstreams can require mTLS
- [gateway] static configuration supports node aliases
- [admin] service registry node upstreams are displayed in the upstreams section
- [admin] gateway and proxy configuration is folded in service registry records
- [auth] EPMD cluster hosts can be configured with `LIBCLUSTER_HOSTS`
- [infra] docker compose runs multiple Boruta nodes with static gateway configuration

### Changed

- [gateway] mesh proxy traffic routes through service registry records
- [admin] upstream creation and edition use service registry records
- [infra] release node distribution and cookie can be configured with environment variables

### Fixed

- [gateway] service registry database notifications remain small when records include certificates and configuration

## [0.9.2] - 2026-06-11

### Added

- [openid] integration tests for OID4VCI credential issuance and OID4VP direct post flows

### Changed

- [wallet] (breaking) credentials and key selection use password-protected local storage
- [gateway] URI strip rewriting only updates the request-line path

### Fixed

- [auth] prompt and request object claims are validated before public client flows
- [auth] prompt none requires a preauthenticated user
- [auth] max age parameters must parse completely
- [auth] WebAuthn state is cleared after authorization errors
- [gateway] upstream TLS hostname verification
- [gateway] HEAD request forwarding
- [gateway] upstream matching ignores query strings and uses the longest matching upstream URI
- [gateway] Authorization headers match bearer token schemes case-insensitively
- [gateway] upstream store notifications are deduplicated
- [gateway] malformed Content-Length responses are handled safely
- [identity] auth flow state is cleared on logout
- [identity] auth return query parameters are parsed correctly
- [identity] sessions are marked chosen after user selection

## [0.9.1] - 2026-06-01

### Added

- [gateway] upstreams can rate-limit traffic
- [gateway] request and business event history in the administration dashboard
- [admin] administrators can see user identifiers in user lists
- [infra] operators can benchmark OAuth grants and gateway requests
- [infra] request count documentation for OAuth and OpenID4VC flows

### Changed

- [auth] OAuth acceptor count can be configured and defaults to 8
- [gateway] gateway acceptor count can be configured
- [gateway] authorization returns clearer OAuth error responses
- [gateway] upstream authorization includes configured scopes
- [gateway] keepalive tuning is removed from gateway configuration
- [infra] deployment secrets are provided through environment variables
- [admin] gateway configuration fields are easier to read
- [admin] user displays prefer usernames over emails

### Fixed

- [admin] verifiable credential array claims can be deleted
- [admin] feedback form
- [admin] gateway dashboard request times graph
- [gateway] upstream routes match paths correctly
- [gateway] empty forwarded token headers are ignored
- [gateway] successful requests appear in logs
- [identity] users are redirected correctly after federated sign in
- [identity] federation error pages render correctly

### Security

- [admin][identity] upgrade vulnerable npm packages
- [auth] OAuth token state values are handled without atom exhaustion risk
- [gateway] reduce exposure of local runtime artifacts in container builds
- [gateway] malformed requests are handled more safely
- [identity] user settings values are handled without atom exhaustion risk
- [identity] development environment defaults are sanitized
- [infra] aggregate log responses are size-limited
- [infra] redact OAuth credentials from logs
- [infra] remove local deployment secrets
- [web] close presentation SSE streams when clients disconnect
- [web] require secure cookies

## [0.9.0] - 2026-05-18

### Added

- [ssi] code chains
    - verify verifiable presentation from code chains
    - issuance code chains
    - next flow redirection in case of presentation success
    - agent token management
- [ssi] code metadata policies
    - restrict issuance / presentation key usage for enabled check public client id clients
- [ssi] server sent events verifiable presentation page navigation
- [identity] add resource owner in credentials templates
- [ssi] credential issuance scope restriction
- [wallet] display credential presentation purposes
- [admin] home page selective login

### Changed

- [ssi] remove resource owner constraint for openid4vc flows
- [ssi] default backend authorization details for anonymous users
- [ssi] issuance / presentation default templates open integrated wallet in a popup
- [ssi] add client_id to credential offers
- [identity] improve identity providers querying and cache
- [admin] group direct post requests in dashboard
- [infra] rate limit boruta identity requests
- [admin] set backend as default in example configuration
- [admin] improve administration login
- [ssi] local did creation / resolution
- [infra] database pool management

### Fixed

- [admin] add credential offer and presentation in breadcrumb
- [admin] update identity provider title in breadcrumb
- [admin] feedback stars display
- [wallet] qr code scan redirection
- [ssi] public and unknown users presentation
- [infra] halt request on 429 rate limit response
- [admin] fix key pair management display

### Security

- [admin] only expose client name in templates
- [auth] remove default client secret from seeds
- [admin] set minimum oauth client private key modulus size
- [auth] set 2048 as minimum rsa keys modulus

## [0.8.0] - 2025-07-12

### Added

- [auth] agent credentials / code flows
- [wallet] key selection
- [ssi] verify public client id oauth client option

### Changed

- [auth] max authorization code ttl to 600 seconds
- [ssi] remove authentication on siopv2 flow

### Fixed

- [admin] file upload text editor update
- [ssi] expose public credential configuration for authenticated users
- [wallet] fix presentation duplicates

### Security

- [auth] experimental request rate limiting
- [auth] remove dynamic client registration

## [0.7.2] - 2025-04-13

### Fixed

- [auth] fix boruta core migration

## [0.7.1] - 2025-04-05

### Fixed

- [ssi] do not use ES256 alg to verify EdDSA JWTs
- [identity] expose default templates static assets

## [0.7.0] - 2025-03-26

### Added

- [admin] signatures adapter
- [wallet] display an error when no credential match presentation
- [identity] add reload button in credentials temapltes
- [wallet] close qr code scanner on click

### Security

- [wallet] fix npm vulnerabilities
- [admin] fix npm vulnerabilities

## [0.6.1] - 2025-03-15

### Security

- [admin] update verifiable presentations default template

## [0.6.0] - 2025-03-15

### Added

- [identity] passwordless user creation (WIP)
- [identity] destroy user
- [ssi] transaction code in OID4VCI preauthorized code flow
- [ssi] vct configuration in verifiable credentials
- [admin] feedback form
- [wallet] web identity wallet bootstrap (PWA)
- [identity] scope user emails per backend
- [admin] decentralized identity example flows
- [ssi] verifiable credentials nested claims

### Changed

- [identity] remove user metadata value constraints
- [admin] verifiable credentials claim format

### Fixed

- [admin] defered configuration
- [admin] example credential issuance link
- [ssi] oauth clients did persistence
- [admin] verifiable presentation definition text edition

### Security

- [admin] remove cdnjs dependency
- [identity] remove picsum dependency

## [0.5.1] - 2024-11-21

### Added

- [admin] user csv import metadata
- [infra] organization creation in static configuration
- [admin] client key pair configuration + support for EC keys

### Fixed

- [ssi] several verifiable credentials issuance and presentation fixes
- [auth] configurable status display in id_token claims
- [admin] user with empty metadata save
- [admin] federated users deletion

## [0.5.0] - 2024-10-17

### Added

- [ssi] OpenID for Verifiable Credentials Presentation implementation

## [0.4.2] - 2024-09-20

### Fixed

- [auth] fix authorize entrypoint

## [0.4.1] - 2024-09-18

### Fixed

- [admin] ipv6 log display

### Security

- [infra] remove .env.example.sig as suspicious file

## [0.4.0] 2024-09-01

### Added

- [ssi] Configurable verifiable credentials issuance with oid4vci implementation
- [ssi] Siopv2 same device implementation
- [auth] Demonstration proof of possession implementation
- [auth] Pushed Authorization Request implementation
- [infra] Server ip address bindings configuration via environment variables
- [infra]Infrastructure as Code with static file configuration
- [admin] Admin ui improvements
- [auth] Better identity federation
- [identity] Webauthn integration
- [infra] Remote IP logging

### Security

- [admin] instance authenticated admins are sub or organization restricted

### Fixed

- [infra] Fix organization and sub admin access restriction

## [0.3.0] 2024-01-18

### Added

- [identity] user organisation management
- [identity] TOTP second factor support
- [identity] user roles management
- [infra] split auth/admin/gateway/all docker images
- [infra] split gateway, admin, auth releases
- [infra] system wide installation script
- [infra] gather statistical info on installation

## [0.2.0] - 2023-05-17

### Added

- [gateway] introspected token forwarding to updatreams
- [identity] email templates edition
- [identity] configure, expose and edit user metadata
- [identity] user metadata configuration
- [gateway] static configuration
- [gateway] microgateways
- [identity] identity federation (login with button)
- [auth] better well-known openid configuration
- [auth] dynamic client registration
- [auth] client authentication methods configuration
- [auth] global signing key pairs


### Security

- [identity] invalidate user reset password token at use

## [0.1.0] - 2022-10-25

Initial beta release
