defmodule BorutaGateway.Repo.Migrations.RemovePoolConfigurationFromUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      remove(:pool_size, :integer)
      remove(:pool_count, :integer)
      remove(:max_idle_time, :integer)
    end
  end
end
