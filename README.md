# Boruta.Umbrella

## Requirements
- Elixir >= 1.13
- postgreSQL >= 13
- node ~> 16.5 (if you need to prepare assets)

## Install
```
git clone git@gitlab.com:patatoid/boruta.git
mix deps.get
mix ecto.setup
mix phx.server
```

## Environment variables

| Variable name                      | description         |
| ---------------------------------- | ------------------- |
| `SECRET_KEY_BASE`                  | Will be used a phoenix secret key base, it is defined as an at least 64 cheracters long string. |
| `POSTGRES_USER`                    | Will be the user provided as credentials in postgreSQL connections. |
| `POSTGRES_PASSWORD`                | Will be the password provided as credentials in postgreSQL connections. |
| `POSTGRES_DATABASE`                | Will be the database provided in postgreSQL connections. |
| `POSTGRES_HOST`                    | Will be the host provided in postgreSQL connections. |
| `POOL_SIZE`                        | Will be postgreSQL pool size of each application, the real connection count will be 4 times that value. |
| `K8S_NAMESPACE`                    | If set along with K8S_SELECTOR setup libcluster in order to connect boruta kubernetes nodes together. |
| `K8S_SELECTOR`                     | If set along with K8S_NAMESPACE setup libcluster in order to connect boruta kubernetes nodes together. |
| `BORUTA_ADMIN_OAUTH_CLIENT_ID`     | An uuidv4 string that will be the admin oauth client id. It will be part of the client seeded in the setup task. |
| `BORUTA_ADMIN_OAUTH_CLIENT_SECRET` | A string that will be the admin oauth client secret. It will be part of the client seeded in the setup task. |
| `BORUTA_ADMIN_OAUTH_BASE_URL`      | The URL that represent the base URL of the authorization server admin will use (linked to above client_id and secret, without trailing slash). |
| `BORUTA_ADMIN_EMAIL`               | Will be the first admin email. It will be part of the user seeded in the setup task. |
| `BORUTA_ADMIN_PASSWORD`            | Will be the first admin password. It will be part of the user seeded in the setup task. |
| `BORUTA_ADMIN_HOST`                | The host that represent the host where boruta admin server will be deployed to. |
| `BORUTA_ADMIN_PORT`                | The port that represent the port where boruta admin server will be exposed on. |
| `BORUTA_ADMIN_BASE_URL`            | The URL that represent the base URL where boruta admin server http endpoint will be deployed to (without trailing slash). |
| `BORUTA_ADMIN_BASE_SOCKET_URL`     | The URL that represent the base URL where boruta admin server websocket endpoint will be deployed to (without trailing slash). |
| `BORUTA_OAUTH_HOST`                | The host that represent the host where boruta oauth server will be deployed to. |
| `BORUTA_OAUTH_PORT`                | The port that represent the port where boruta oauth server will be exposed on. |
| `BORUTA_OAUTH_BASE_URL`            | The URL that represent the base URL where boruta oauth server http endpoint will be deployed to (without trailing slash). |
| `MAILJET_API_KEY`                  | TODO Have the ability to choose emailing provider. |
| `MAILJET_SECRET`                   | TODO Have the ability to choose emailing provider. |

## Run a release from scratch

1. first you need to prepare assets in order for them to be included in the release

```bash
./scripts/prepare_assets.sh
```

2. then you can craft the release

```bash
MIX_ENV=prod mix release
```

3. finally setup database

```bash
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta eval "Boruta.Release.setup()"
```

Once done, you can run the release as follow:

```bash
env $(cat .env.example | xargs) _build/prod/rel/boruta/bin/boruta start
```

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
