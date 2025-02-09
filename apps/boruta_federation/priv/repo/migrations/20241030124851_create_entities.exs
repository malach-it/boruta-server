defmodule BorutaFederation.Repo.Migrations.CreateEntities do
  use Ecto.Migration

  def change do
    create table(:federation_entities, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_name, :string, null: false
      add :type, :string, null: false
      add :public_key, :text, null: false
      add :private_key, :text, null: false
      add :key_pair_type, :jsonb, null: false, default: """
      {
        "type": "rsa",
        "modulus_size": "1024",
        "exponent_size": "65537"
      }
      """
      add :trust_chain_statement_alg, :string, default: "RS256"

      timestamps()
    end
  end
end
