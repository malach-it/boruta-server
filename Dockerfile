FROM elixir:1.8.1-alpine

ENV APP_VERSION 0.1.0-rc.1

RUN apk add --no-cache bash build-base git nodejs nodejs-npm

RUN mix local.hex --force
RUN mix local.rebar --force

COPY . /tmp/boruta

WORKDIR /tmp/boruta/apps/boruta_web/assets
RUN npm ci
WORKDIR /tmp/boruta/apps/boruta_web
RUN MIX_ENV=prod mix phx.digest

WORKDIR /tmp/boruta
RUN mix do clean, deps.get
RUN MIX_ENV=prod mix distillery.release --env=prod

RUN mkdir /app
RUN cp ./_build/prod/rel/boruta_umbrella/releases/$APP_VERSION/boruta_umbrella.tar.gz /app/boruta_umbrella.tar.gz

WORKDIR /app
RUN rm -rf /tmp/boruta

RUN tar -xzf boruta_umbrella.tar.gz
RUN rm boruta_umbrella.tar.gz

EXPOSE 4000
CMD ["/bin/sh", "-c", "/app/bin/boruta_umbrella foreground"]
