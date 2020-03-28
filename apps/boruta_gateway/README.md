# BorutaGateway

**TODO: Add description**

## Benchmark
1. setup the app
```
mix deps.get
mix ecto.create
mix ecto.migrate
mix run apps/boruta_gateway/priv/repo/seeds.exs
```

2. run
```
mix phx.server | grep warn
```

All warn outputs are the passthrough times for requests
