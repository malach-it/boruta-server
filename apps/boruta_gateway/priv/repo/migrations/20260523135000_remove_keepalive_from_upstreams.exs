defmodule BorutaGateway.Repo.Migrations.RemoveKeepaliveFromUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      remove_if_exists(:keepalive, :boolean)
    end
  end
end
