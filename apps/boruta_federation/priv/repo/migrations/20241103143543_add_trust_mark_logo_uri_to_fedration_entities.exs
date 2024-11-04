defmodule BorutaFederation.Repo.Migrations.AddTrustMarkLogoUriToFedrationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :trust_mark_logo_uri, :string
    end
  end
end
