FROM node:17.4.0 AS assets

# For packages not compatible with OpenSSL 3.0 https://nodejs.org/en/blog/release/v17.0.0/
ENV NODE_OPTIONS=--openssl-legacy-provider

WORKDIR /app

COPY ./apps/boruta_admin/assets /app

RUN npm ci
RUN npm run build

FROM elixir:1.13.4-slim AS builder

RUN apt-get update
RUN apt-get install -y git build-essential

ENV MIX_ENV=prod

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /app
COPY . .
COPY --from=assets /priv ./apps/boruta_admin/priv/
RUN rm -rf deps
RUN mix do clean, deps.get
RUN mix compile

WORKDIR /app/apps/boruta_admin
RUN mix phx.digest
WORKDIR /app/apps/boruta_identity
RUN mix phx.digest
WORKDIR /app/apps/boruta_web
RUN mix phx.digest

WORKDIR /app
RUN mix release --force --overwrite

FROM elixir:1.13.4-slim

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
