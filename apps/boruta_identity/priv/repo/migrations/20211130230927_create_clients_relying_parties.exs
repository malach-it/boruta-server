defmodule BorutaIdentity.Repo.Migrations.CreateClientsRelyingParties do
  use Ecto.Migration

  def change do
    create table(:clients_relying_parties, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :relying_party_id, references(:relying_parties, type: :uuid, on_delete: :delete_all), null: false
      add :client_id, :uuid, null: false

      timestamps()
    end

    create index("clients_relying_parties", [:client_id], unique: true)
  end
end
