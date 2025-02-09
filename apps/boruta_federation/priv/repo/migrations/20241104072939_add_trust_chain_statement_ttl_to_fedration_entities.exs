defmodule BorutaFederation.Repo.Migrations.AddTrustChainStatementTtlToFedrationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :trust_chain_statement_ttl, :integer, null: false, default: 3600 * 24
    end
  end
end
