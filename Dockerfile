FROM elixir:1.10.4-alpine AS builder

RUN apk add curl-dev openssl-dev libevent-dev git make build-base nodejs npm

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app
COPY . .
RUN rm -rf deps
RUN mix do clean, deps.get

WORKDIR /app/apps/boruta_web/priv/assets
RUN npm ci

WORKDIR /app
RUN MIX_ENV=prod mix release --force --overwrite

FROM elixir:1.10.4-alpine

RUN apk add curl-dev openssl-dev libevent-dev nodejs npm

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
