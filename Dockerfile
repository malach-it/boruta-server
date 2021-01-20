FROM node:14.5.0 AS assets

ENV VUE_APP_ADMIN_CLIENT_ID=6a2f41a3-c54c-fce8-32d2-0324e1c32e20
# TODO build once run everywhere ? at least arg ?
ENV VUE_APP_BORUTA_BASE_URL=http://boruta.local
ENV VUE_APP_BORUTA_BASE_SOCKET_URL=ws://boruta.local

WORKDIR /app

COPY ./apps/boruta_web/assets /app

RUN npm ci
RUN npm run build

FROM elixir:1.10.4-alpine AS builder

RUN apk add curl-dev openssl-dev libevent-dev git make build-base erlang-erl-interface

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app
COPY . .
RUN rm -rf deps
RUN mix do clean, deps.get

COPY --from=assets /priv ./apps/boruta_web/priv/
WORKDIR /app/apps/boruta_web
RUN MIX_ENV=prod mix phx.digest

WORKDIR /app
RUN MIX_ENV=prod mix release --force --overwrite

FROM elixir:1.10.4-alpine

RUN apk add curl-dev openssl-dev libevent-dev

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
