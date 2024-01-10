defmodule BorutaIdentity.Repo.Migrations.AddFederatedMetadataToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :federated_metadata, :jsonb, default: "{}"
    end
  end
end
