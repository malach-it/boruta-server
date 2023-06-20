# example configurations

## Sidecar authorization gateways

located at `examples/sidecar-authorization-gateways`


1. run database migrations

```bash
docker-compose run boruta-server ./bin/boruta eval "BorutaWeb.Release.setup()"
docker-compose run boruta-server ./bin/boruta eval "BorutaGateway.Release.setup()"
```

2. load (micro)gateways configuration

```
docker-compose run boruta-server ./bin/boruta eval "BorutaGateway.Release.load_configuration()"
docker-compose run httpbin-sidecar ./bin/boruta_gateway eval "BorutaGateway.Release.load_configuration()"
docker-compose run protected-httpbin-sidecar ./bin/boruta_gateway eval "BorutaGateway.Release.load_configuration()"
```

Once done, you can run the docker images as follow:

```bash
docker-compose up
```

The applications will be available on different ports (depending on the docker compose environment configuration):
- http://localhost:8080 for the authorization server
- http://localhost:8081 for the admin interface
- http://localhost:8082 for the gateway

The gateway will have two endpoints:
- `http://localhost:8082/httpbin` which expose the httpbin service publicly
- `http://localhost:8082/protected-httpbin` which expose the httpbin and restrict traffic to test scope granted users
