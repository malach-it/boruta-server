defmodule BorutaGateway.Repo.Migrations.AddRateLimitingToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:rate_limit_enabled, :boolean, default: false)
      add(:rate_limit_count, :integer, default: 10)
      add(:rate_limit_time_unit, :string, default: "second")
      add(:rate_limit_penality, :integer, default: 500)
      add(:rate_limit_timeout, :integer, default: 5_000)
    end
  end
end
