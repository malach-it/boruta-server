defmodule BorutaGateway.Repo.Migrations.AddKeepaliveToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:keepalive, :boolean, default: false, null: false)
    end
  end
end
