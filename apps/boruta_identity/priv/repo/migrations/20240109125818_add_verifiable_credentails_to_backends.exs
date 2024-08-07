defmodule BorutaIdentity.Repo.Migrations.AddVerifiableCredentailsToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :verifiable_credentials, {:array, :jsonb}, default: []
    end
  end
end
