![logo-yellow](images/logo-yellow.png)

Boruta is an authorization server implementing OAuth 2.0 and Openid Connect specifications. It provides administration tools and a customizable identity provider out of the box to manage authorization, but also a gateway to apply access rules to incoming traffic.

## Requirements
- Elixir >= 1.13
- postgreSQL >= 13
- node >= 16.5 (if you need to prepare assets)

## Environment variables

| Variable name                      | description         |
| ---------------------------------- | ------------------- |
| `SECRET_KEY_BASE`                  | The Phoenix secret key base. It must be at least 64 cheracters long. |
| `POSTGRES_USER`                    | The database user provided as credentials in postgreSQL connections. |
| `POSTGRES_PASSWORD`                | The database password provided as credentials in postgreSQL connections. |
| `POSTGRES_DATABASE`                | The database name provided in postgreSQL connections. |
| `POSTGRES_HOST`                    | The database host provided in postgreSQL connections. |
| `POOL_SIZE`                        | The postgreSQL pool size of each application, the real connection count will be 4 times that value. |
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
| `BORUTA_ADMIN_BASE_SOCKET_URL`     | The base URL where boruta admin server websocket endpoint will be deployed to (without trailing slash). |
| `BORUTA_OAUTH_HOST`                | The host where boruta oauth server will be deployed to. |
| `BORUTA_OAUTH_PORT`                | The port where boruta oauth server will be exposed on. |
| `BORUTA_OAUTH_BASE_URL`            | The base URL where boruta oauth server http endpoint will be deployed to (without trailing slash). |
| `BORUTA_GATEWAY_PORT`              | The port where boruta gateway will be exposed on. |
| `MAILJET_API_KEY`                  | TODO Have the ability to choose emailing provider. |
| `MAILJET_SECRET`                   | TODO Have the ability to choose emailing provider. |

## Run an instance from docker-compose

1. build the docker images

```bash
docker-compose build
```

2. run database migrations

```bash
docker-compose run boruta ./bin/boruta eval "Boruta.Release.setup()"
```

Once done, you can run the docker images as follow:

```bash
docker-compose up
```

The applications will be available on different ports (depending on the docker compose environment configuration):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway

## Run a release from scratch

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
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta eval "Boruta.Release.setup()"
```

Once done, you can run the release as follow:

```bash
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta start
```

The applications will be available on different ports (depending on the values provided in `.env.example`):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway

## Run a development server

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

## Default admin credentials

In order to authenticate to the administration interface you will be asked for credentials that are by default (seeded from environment variables) `admin@test.test` / `imaynotknowthat`.
