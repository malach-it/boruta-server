![logo-yellow](images/logo-yellow.png)

Boruta is a standalone authorization server implementing OAuth 2.0 and Openid Connect specifications. It provides administration tools and a customizable identity provider out of the box to manage authorization, but also a gateway to apply access rules to incoming traffic.

## Status

This server is on an ongoing beta stage. Developments are moving fast on master then are keen to be less stable. Tagged versions are said to be more stable and sanity tested.

As far as I know, there are no production deployments of the server. I would be happy to contribute to deployments if ones want to go for it. Reach out, we can discuss the needs of your use case.

## Implemented specifications and certification

As it, boruta server aim to follow the RFCs from IETF:
- [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)
- [RFC 7009 - OAuth 2.0 Token Revocation](https://tools.ietf.org/html/rfc7009)
- [RFC 7636 - Proof Key for Code Exchange by OAuth Public Clients](https://tools.ietf.org/html/rfc7636)
- [RFC 7521 - Assertion Framework for OAuth 2.0 Client Authentication and Authorization Grants](https://www.rfc-editor.org/rfc/rfc7521)
- [RFC 7523 - JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication and Authorization Grants](https://tools.ietf.org/html/rfc7523)

And the specifications from the OpenID Foundation:
- [OpenID Connect core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [OpenID Connect Dynamic Client Registration 1.0 incorporating errata set 1](https://openid.net/specs/openid-connect-registration-1_0.html)

This server has been certified for the Basic, Implicit, and Hybrid OpenID Provider profiles by the OpenID Foundation on October, 18th 2022 for the tagged version 0.1.0

This server has been also certified for the Config and Dynamic OpenID Provider profiles by the OpenID Foundation on May, 16th 2023 for the tagged version 0.2.0

![OpenID certified](https://github.com/malach-it/boruta-server/blob/master/images/oid-certification-mark.png?raw=true)

## Installation

A [loom presentation](https://www.loom.com/share/77006360fdac44bc9113fab9cf30aba5) about how to get a server up and running.

### Run an instance from docker

A docker image is available at `malachit/boruta-server` on [DockerHub](https://hub.docker.com/r/malachit/boruta-server), you will need a postgres instance installed on your system with credentials provided as environment variables in `.env.*`.

1. Run database migrations

```bash
docker run --env-file .env.dev --network=host malachit/boruta-server:0.2.0 ./bin/boruta eval "Boruta.Release.setup()"
```

Once done you will be able to launch the server.

```bash
docker run --env-file .env.dev --network=host malachit/boruta-server:0.2.0
```

The applications will be available on different ports (depending on the values provided in `.env.dev`):
- http://localhost:4000 for the authorization server
- http://localhost:4001 for the admin interface
- http://localhost:4002 for the gateway
- http://localhost:4003 for the microgateway

Admin credentials are the one seeded and available in environment file.

### Run an instance from docker-compose

1. build the docker images

```bash
docker-compose build
```

2. run database migrations

```bash
docker-compose run boruta ./bin/boruta eval "BorutaWeb.Release.setup()"
docker-compose run boruta ./bin/boruta eval "BorutaGateway.Release.setup()"
```

Once done, you can run the docker images as follow:

```bash
docker-compose up
```

The applications will be available on different ports (depending on the docker compose environment configuration):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway
- http://localhost:8083 for the microgateway

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
MIX_ENV=prod mix release
```

4. finally setup database

```bash
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta eval "BorutaWeb.Release.setup()"
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta eval "BorutaGateway.Release.setup()"
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

### Run a development server

1. first you need to get project dependencies

```bash
mix deps.get
```

2. you need to prepare assets in order to fetch javascript dependencies

```bash
./scripts/prepare_assets.sh
```

3. create, migrate and seed database

```bash
env $(cat .env.dev | xargs) mix ecto.create
env $(cat .env.dev | xargs) mix ecto.migrate
env $(cat .env.dev | xargs) mix run apps/boruta_auth/priv/repo/boruta.seeds.exs
```

4. because of the forwarding of requests between web and identity modules, you need to add the `/accounts` path prefix in configuration

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

| Variable name                      | description         |
| ---------------------------------- | ------------------- |
| `SECRET_KEY_BASE`                  | The Phoenix secret key base. It must be at least 64 cheracters long. |
| `POSTGRES_USER`                    | The database user provided as credentials in postgreSQL connections. |
| `POSTGRES_PASSWORD`                | The database password provided as credentials in postgreSQL connections. |
| `POSTGRES_DATABASE`                | The database name provided in postgreSQL connections. |
| `POSTGRES_HOST`                    | The database host provided in postgreSQL connections. |
| `POOL_SIZE`                        | The postgreSQL pool size of each application, the real connection count will be twice that value. |
| `MAX_LOG_RETENTION_DAYS`           | The number of days the logs are kept to the server. This value defaults to 60. |
| `K8S_NAMESPACE`                    | If set along with K8S_SELECTOR, it setups libcluster in order to connect boruta erlang nodes in kubernetes together. |
| `K8S_SELECTOR`                     | If set along with K8S_NAMESPACE, it setups libcluster in order to connect boruta erlang nodes in kubernetes together. |
| `BORUTA_ADMIN_OAUTH_CLIENT_ID`     | An uuidv4 string representing the admin oauth client id. It will be part of the client seeded in the setup task. |
| `BORUTA_ADMIN_OAUTH_CLIENT_SECRET` | The admin oauth client secret. It will be part of the client seeded in the setup task. |
| `BORUTA_ADMIN_OAUTH_BASE_URL`      | The URL base URL of the authorization server admin will use (linked to above client_id and secret, without trailing slash). |
| `BORUTA_ADMIN_EMAIL`               | The first admin email. It will be part of the user seeded in the setup task. |
| `BORUTA_ADMIN_PASSWORD`            | The first admin password. It will be part of the user seeded in the setup task. |
| `BORUTA_ADMIN_HOST`                | The host that represent the host where boruta admin server will be deployed to. |
| `BORUTA_ADMIN_PORT`                | The port where boruta admin server will be exposed on. |
| `BORUTA_ADMIN_BASE_URL`            | The base URL where boruta admin server http endpoint will be deployed to (without trailing slash). |
| `BORUTA_OAUTH_HOST`                | The host where boruta oauth server will be deployed to. |
| `BORUTA_OAUTH_PORT`                | The port where boruta oauth server will be exposed on. |
| `BORUTA_OAUTH_BASE_URL`            | The base URL where boruta oauth server http endpoint will be deployed to (without trailing slash). |
| `BORUTA_GATEWAY_PORT`              | The port where boruta gateway will be exposed on. |
| `BORUTA_GATEWAY_SIDECAR_PORT`      | The port where boruta microgateway will be exposed on. |
| `BORUTA_GATEWAY_CONFIGURATION_PATH`| The path containing the gateway static configuration. |
| `BORUTA_SUB_RESTRICTED`            | The uid of the only user to have access to the administration interface. |

## Code of Conduct

This product community follows the code of conduct available [here](https://io.malach.it/code-of-conduct.html)

## License

This code is released under the [Apache 2.0](LICENSE.md) license.
