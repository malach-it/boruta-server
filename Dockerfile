FROM node:14.5.0 AS assets

WORKDIR /app

COPY ./apps/boruta_web/assets /app

RUN npm ci
RUN npm run build

FROM elixir:1.11.2 AS builder

RUN apt-get update
RUN apt-get install -y npm libcurl4-openssl-dev libssl-dev libevent-dev

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app
COPY . .

COPY --from=assets /priv/* ./apps/boruta_web/priv/
WORKDIR /app/apps/boruta_web
RUN MIX_ENV=prod mix phx.digest

WORKDIR /app
RUN mix do clean, deps.get
RUN MIX_ENV=prod mix release --force --overwrite

FROM elixir:1.11.2-slim

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
