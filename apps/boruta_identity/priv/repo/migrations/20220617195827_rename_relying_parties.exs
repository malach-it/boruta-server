defmodule BorutaIdentity.Repo.Migrations.RenameRelyingParties do
  use Ecto.Migration

  def change do
    drop index(:relying_parties, [:name])
    drop constraint(:clients_relying_parties, "clients_relying_parties_relying_party_id_fkey")
    drop constraint(:relying_party_templates, "relying_party_templates_relying_party_id_fkey")

    rename table(:relying_parties), to: table(:identity_providers)
    rename table(:relying_party_templates), to: table(:identity_provider_templates)
    rename table(:clients_relying_parties), to: table(:clients_identity_providers)

    rename table(:identity_provider_templates), :relying_party_id, to: :identity_provider_id
    alter table(:identity_provider_templates) do
      modify :identity_provider_id, references(:identity_providers, type: :binary_id, on_delete: :delete_all)
    end

    rename table(:clients_identity_providers), :relying_party_id, to: :identity_provider_id
    alter table(:clients_identity_providers) do
      modify :identity_provider_id, references(:identity_providers, type: :binary_id, on_delete: :delete_all)
    end

    create index(:identity_providers, [:name], unique: true)
  end
end
