defmodule BorutaGateway.Repo.Migrations.AddRateLimitMemoryLengthToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:rate_limit_memory_length, :integer, default: 50)
    end
  end
end
