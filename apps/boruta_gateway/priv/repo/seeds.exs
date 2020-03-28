alias BorutaGateway.Upstreams.Upstream

BorutaGateway.Repo.insert(%Upstream{
  scheme: "http",
  host: "localhost",
  port: 4001,
  uris: ["/"]
})
