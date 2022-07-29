defmodule BorutaGateway.Repo.Migrations.AddPoolCountToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :pool_count, :integer, default: 1, null: false
    end
  end
end
