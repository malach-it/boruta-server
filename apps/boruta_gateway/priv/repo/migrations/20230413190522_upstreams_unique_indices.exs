defmodule BorutaGateway.Repo.Migrations.UpstreamsUniqueIndices do
  use Ecto.Migration

  def change do
    create index(:upstreams, [:host, :port, :uris], unique: true)
  end
end
