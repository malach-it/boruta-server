# Optional Mnesia gateway repository

`BorutaGateway.Repo` uses PostgreSQL by default. To build it with
`ecto3_mnesia` 0.3.0 instead, set `BORUTA_GATEWAY_BACKEND=mnesia` **before
compiling** the umbrella or building a release. Ecto selects the adapter at
compile time, so changing this variable on an existing release does not switch
its repository.

Set `BORUTA_GATEWAY_MNESIA_DIR` to an absolute path on persistent storage. The
gateway creates the Mnesia schema and the `upstreams` and
`service_registry_records` tables when it starts. The default path is intended
for local development only. Each Mnesia node needs a stable Erlang node name and
its own data directory. Deployments with more than one node also need a planned
Mnesia clustering and recovery setup.

For example, from the umbrella root:

```sh
BORUTA_GATEWAY_BACKEND=mnesia \
BORUTA_GATEWAY_MNESIA_DIR=/var/lib/boruta/gateway-mnesia \
mix compile --force
```

When switching an existing build between PostgreSQL and Mnesia, run
`mix compile --force` with the new environment setting before starting it.

`boruta_auth` and the other umbrella repositories still use PostgreSQL. Admin
reads and writes gateway upstreams through `BorutaGateway.Repo`, so an admin
release must be built with the same backend and reach the same Mnesia cluster.
The Mnesia directory starts empty; existing PostgreSQL gateway rows are not
copied automatically.

The Mnesia adapter uses schema-based table creation rather than the gateway's
SQL migrations. Startup checks table attributes and fails if an existing table
does not match the current schema. Move the data with an explicit Mnesia schema
migration before upgrading across gateway schema changes. The gateway context
enforces the upstream uniqueness rule with a Mnesia table lock; direct writes to
the repo bypass that check.
