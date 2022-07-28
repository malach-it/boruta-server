defmodule BorutaGateway.Repo.Migrations.AddMaxIdleTimeToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :max_idle_time, :integer, default: 10, null: false
    end
  end
end
