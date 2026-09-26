![logo-yellow](images/logo-yellow.png)

boruta is a standalone authorization server that aims to implement OAuth 2.0 and Openid Connect up to decentralized identity specifications. It provides administration tools and a customizable identity provider out of the box to manage authorization, but also an experimental gateway to apply access rules to incoming traffic.

## Status

boruta is currently in an __open beta phase__, if you are interested in the project and the tools it provides, you are encourage to test the software within your context. Production readyness will depend on your feedback, helping to fix the possible bugs and improve the solution usability. While being mostly stable and security asessed for some of its parts, boruta is a work in progress, please read the [General Terms and Conditions](GENERAL_TERMS_AND_CONDITIONS.md).

## Implemented specifications and certification

As it, boruta server aim to follow the RFCs from IETF:
- [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)
- [RFC 7009 - OAuth 2.0 Token Revocation](https://tools.ietf.org/html/rfc7009)
- [RFC 7636 - Proof Key for Code Exchange by OAuth Public Clients](https://tools.ietf.org/html/rfc7636)
- [RFC 7521 - Assertion Framework for OAuth 2.0 Client Authentication and Authorization Grants](https://www.rfc-editor.org/rfc/rfc7521)
- [RFC 7523 - JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication and Authorization Grants](https://tools.ietf.org/html/rfc7523)
- [RFC 9449 - OAuth 2.0 Demonstrating Proof-of-Possession at the Application Layer (DPoP)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-dpop)
- [RFC 9126 - OAuth 2.0 Pushed Authorization Requests](https://datatracker.ietf.org/doc/html/rfc9126)

And the specifications from the OpenID Foundation:
- [OpenID Connect core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [OpenID Connect Dynamic Client Registration 1.0 incorporating errata set 1](https://openid.net/specs/openid-connect-registration-1_0.html)
- [OpenID for Verifiable Credential Issuance](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [Self-Issued OpenID Provider v2](https://openid.net/specs/openid-connect-self-issued-v2-1_0.html)
- [OpenID for Verifiable Presentations - draft 21](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)

This server has been certified for the Basic, Implicit, and Hybrid OpenID Provider profiles by the OpenID Foundation on October, 18th 2022 for the tagged versions 0.1.0 and 0.5.0

This server has been certified for the Config and Dynamic OpenID Provider profiles by the OpenID Foundation on May, 16th 2023 for the tagged version 0.2.0

This server has also been certified against the [European Blockchain Service Infrastructure (EBSI)](https://ec.europa.eu/digital-building-blocks/sites/display/EBSI) issuance test suite for the tagged version 0.4.0 and for verifiable credential verification for the tagged version 0.5.0.

![EBSI certified - issue](https://github.com/malach-it/boruta-server/blob/master/images/ebsi-certification-issuance.png?raw=true)
![EBSI certified - verify](https://github.com/malach-it/boruta-server/blob/master/images/ebsi-certification-verify.png?raw=true)
![OpenID certified](https://github.com/malach-it/boruta-server/blob/master/images/oid-certification-mark.png?raw=true)

## Documentation

Server documentation is available on github pages [here](https://malach-it.github.io/documentation.boruta/docs/intro). It highlights how the server works, describing its architecture, parameters and the associated authentication / authorization flows. It is a Work In Progress, all feedback or contributions would be welcomed.

## DID creation and resolution

boruta may use [Universal resolver](https://github.com/decentralized-identity/universal-resolver) for DID resolution and [Universal registrar](https://github.com/decentralized-identity/universal-registrar) for DID creation. Those are to be configured as environment variables, respectively `DID_RESOLVER_BASE_URL` and `DID_REGISTRAR_BASE_URL`. DIDs are used in the decentralized identity flows and are present as key identifier header of the other generated JWTs.

## Integrated wallet

This project includes a demo wallet implemented for testing purposes. It is compliant with the decentralized identity flows but does not have neither secure storage nor portability features which makes it not production ready. Note that even if those features come in further releases, this wallet does not target to be an EUDI wallet as the European framework states.

## Installation

The easiest way to try the server is by using docker compose as follow:

### Run an instance from docker-compose

You can build and run the docker images as follow:

```bash
docker-compose up
```

The applications will be available on different ports (depending on the docker compose environment configuration):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway
- http://localhost:8083 for the microgateway

Admin credentials are the one seeded and available in environment file.

### Run an instance from docker

> Note this image is built for x86_64 architecture, for other architectures build yourself the image or use docker compose install that will build the image for your architecture.

A docker image is available at `malachit/boruta-server` on [DockerHub](https://hub.docker.com/r/malachit/boruta-server), you will need a postgres instance installed on your system with credentials provided as environment variables in `.env.*`.

1. Get environment file

```bash
wget https://raw.githubusercontent.com/malach-it/boruta-server/master/.env.dev
```

Once done you will be able to launch the server.

```bash
docker run -it --env-file .env.dev --network=host malachit/boruta-server:0.4.0
```

The applications will be available on different ports (depending on the values provided in `.env.dev`):
- http://localhost:4000 for the authorization server
- http://localhost:4001 for the admin interface
- http://localhost:4002 for the gateway
- http://localhost:4003 for the microgateway

Admin credentials are the one seeded and available in environment file.

### Requirements
- Elixir >= 1.13
- postgreSQL >= 13
- node >= 16.5 (if you need to prepare assets)

### Run a release from scratch

1. first you need to get project dependencies

```bash
mix deps.get
```

2. you need to prepare assets in order for them to be included in the release

```bash
./scripts/prepare_assets.sh
```

3. then you can craft the release

```bash
MIX_ENV=prod mix release boruta
```

Once done, you can run the release as follow:

```bash
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta start
```

The applications will be available on different ports (depending on the values provided in `.env.example`):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway
- http://localhost:8083 for the microgateway

Admin credentials are the one seeded and available in environment file.

### Command line interface

The `boruta` and `boruta_admin` releases include `bin/boruta-cli`, which uses the following syntax:

CLI commands authenticate the admin OAuth client using
`BORUTA_ADMIN_OAUTH_CLIENT_ID` and `BORUTA_ADMIN_OAUTH_CLIENT_SECRET`.

```text
boruta-cli <resource> <action> [resource-id] [response-filter ...] [-- action-parameter ...]
```

```bash
bin/boruta-cli role index
bin/boruta-cli client show CLIENT_ID id name
bin/boruta-cli upstream update UPSTREAM_ID -- scheme:https port:443
bin/boruta-cli client update CLIENT_ID -- identity_provider:id:IDENTITY_PROVIDER_ID
bin/boruta-cli logs index request_id status label -- events_only:true
```

Arguments before `--` filter the YAML response, while action parameters after `--` are sent to the controller and must use `key:value` syntax. Colon-separated parameter segments create nested maps, and numeric segments address zero-based array indices. For example, `backend show BACKEND_ID verifiable_credentials:0:claims:0` filters the response to the first claim, while `backend update BACKEND_ID -- verifiable_credentials:0:claims:0:label:"test"` updates its label. Commands without `--` retain legacy parameter parsing, except that indexed paths on read actions are recognized as response filters. Explicit parameters override command defaults.

Use an unquoted `[]` value to send an empty array, for example `client update CLIENT_ID -- redirect_uris:[]` or `backend update BACKEND_ID -- verifiable_credentials:0:claims:[]`. Quote the value as `"[]"` when the literal string is required instead.

### Run a development server

1. first you need to get project dependencies

```bash
mix deps.get
```

2. you need to prepare assets in order to fetch javascript dependencies

```bash
./scripts/prepare_assets.sh
```

3. because of the forwarding of requests between web and identity modules, you need to add the `/accounts` path prefix in configuration

```diff
--- a/apps/boruta_identity/config/config.exs
+++ b/apps/boruta_identity/config/config.exs
@@ -4,8 +4,8 @@ config :boruta_identity,
   ecto_repos: [BorutaAuth.Repo, BorutaIdentity.Repo]

 config :boruta_identity, BorutaIdentityWeb.Endpoint,
-  url: [host: "localhost"],
-  # url: [host: "localhost", path: "/accounts"],
+  # url: [host: "localhost"],
+  url: [host: "localhost", path: "/accounts"],
```

You now should be able to start the development server

```bash
env $(cat .env.dev | xargs) MIX_ENV=dev mix boruta.server
```

The applications will be available on different ports (depending on the values provided in `.env.dev`):
- http://localhost:4000 for the authorization server
- http://localhost:4001 for the admin interface
- http://localhost:4002 for the gateway
- http://localhost:4003 for the microgateway

Admin credentials are the one seeded and available in environment file.

### Default admin credentials

In order to authenticate to the administration interface you will be asked for credentials that are by default (seeded from environment variables) `admin@test.test` / `imaynotknowthat`.

## Environment variables

See [documentation](https://malach-it.github.io/documentation.boruta/docs/provider-configuration/environment-variables)

## Code of Conduct

This product community follows the code of conduct available [here](CODE_OF_CONDUCT.md)

## License

This code is released under the [Apache 2.0](LICENSE.md) license.
Third-party components and administration color palettes are documented in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## General Terms and Conditions

By using Boruta, you agree to the [General Terms and Conditions](GENERAL_TERMS_AND_CONDITIONS.md), which complement the software's Apache 2.0 License.

## About boruta

The name boruta comes from a polish legend where he is a gentle devil (an angel, maybe) that is such evil that having him at home makes you safe. He was living during the middle ages in the castle of the little town of Leczyca, since then the people from there have a little figurine of him at home helping the house to be protected from bad fate.
