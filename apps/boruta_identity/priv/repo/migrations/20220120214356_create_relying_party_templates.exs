defmodule BorutaIdentity.Repo.Migrations.CreateRelyingPartyTemplates do
  use Ecto.Migration

  def change do
    create table(:relying_party_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :relying_party_id, references(:relying_parties, type: :uuid, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :content, :text, default: ""

      timestamps()
    end

    create index(:relying_party_templates, [:relying_party_id, :type], unique: true)
  end
end
