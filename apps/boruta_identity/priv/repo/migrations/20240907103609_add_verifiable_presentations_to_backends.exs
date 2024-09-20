defmodule BorutaIdentity.Repo.Migrations.AddVerifiablePresentationsToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :verifiable_presentations, {:array, :jsonb}, default: []
    end
  end
end
