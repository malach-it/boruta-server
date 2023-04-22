defmodule BorutaGateway.Repo.Migrations.UpdateUpstreamsUniqueConstraint do
  use Ecto.Migration

  def change do
    drop index(:upstreams, [:host, :port, :uris], unique: true)
    create index(:upstreams, [:node_name, :host, :port, :uris], unique: true)
  end
end
