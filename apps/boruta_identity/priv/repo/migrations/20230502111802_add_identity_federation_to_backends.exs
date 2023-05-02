defmodule BorutaIdentity.Repo.Migrations.AddIdentityFederationToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :federated_servers, {:array, :jsonb}, default: []
    end
  end
end
