defmodule BorutaGateway.Repo.Migrations.AddPoolSizeToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:pool_size, :integer, default: 10)
    end
  end
end
