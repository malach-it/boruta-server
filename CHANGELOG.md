# Changelog

> Note that 0.X.X releases are reverved for the beta version of the server and may include breaking changes.

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
