FROM node:14.5.0 AS assets

WORKDIR /app

COPY ./apps/boruta_web/assets /app

RUN npm ci
RUN npm run build

FROM elixir:1.10.4-alpine AS builder

RUN apk add curl-dev openssl-dev libevent-dev git make build-base

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app
COPY . .
COPY --from=assets /priv ./apps/boruta_web/priv/
RUN rm -rf deps
RUN mix do clean, deps.get

WORKDIR /app/apps/boruta_web
RUN MIX_ENV=prod mix phx.digest
WORKDIR /app/apps/boruta_identity
RUN MIX_ENV=prod mix phx.digest

WORKDIR /app
RUN MIX_ENV=prod mix release --force --overwrite

FROM elixir:1.10.4-alpine

RUN apk add curl-dev openssl-dev libevent-dev

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
