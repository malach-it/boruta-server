# Changelog

> Note that 0.X.X releases are reverved for the beta version of the server and may include breaking changes.

## [unreleased]

### Added

- server ip address bindings configuration via environment variables

### Security

- [admin] instance authenticated admins are sub or organization restricted

## [0.3.0] 2024-01-18

### Added

- [identity] user organisation management
- [identity] TOTP second factor support
- [identity] user roles management
- [infra] split auth/admin/gateway/all docker images
- {infra] split gateway, admin, auth releases
- {infra] system wide installation script
- {infra] gather statistical info on installation

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
