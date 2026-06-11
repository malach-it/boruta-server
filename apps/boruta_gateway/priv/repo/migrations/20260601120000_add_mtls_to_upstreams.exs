defmodule BorutaGateway.Repo.Migrations.AddMtlsToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:mtls_enabled, :boolean, default: false, null: false)
    end
  end
end
