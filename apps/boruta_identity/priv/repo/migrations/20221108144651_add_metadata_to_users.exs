defmodule BorutaIdentity.Repo.Migrations.AddMetadataToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :metadata, :jsonb, default: "{}", null: false
    end
  end
end
