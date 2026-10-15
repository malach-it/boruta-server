defmodule BorutaGateway.Repo.Migrations.RemoveKeepaliveFromUpstreams do
  use Ecto.Migration

  def up do
    alter table(:upstreams) do
      remove_if_exists(:keepalive, :boolean)
    end
  end

  def down do
  end
end
