FROM node:16.5.0 AS assets

WORKDIR /app

COPY ./apps/boruta_admin/assets /app

RUN npm ci
RUN npm run build

FROM elixir:1.12.2 AS builder

ENV MIX_ENV=prod

RUN apt-get install -y libcurl4-openssl-dev libssl-dev libevent-dev

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

WORKDIR /app
RUN mix release --force --overwrite

FROM elixir:1.12.2

RUN apt-get install -y libcurl4-openssl-dev libssl-dev libevent-dev

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/boruta ./

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta start"]
