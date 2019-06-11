defmodule Boruta.Repo.Migrations.CreateBoruta do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:secret, :string)
      add(:redirect_uri, :string)
      add(:scope, :string)
      add(:authorize_scope, :boolean, default: false)
      add(:authorized_scopes, {:array, :string}, default: [])

      timestamps()
    end

    create table(:tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:value, :string)
      add(:expires_at, :integer)
      add(:redirect_uri, :string)
      add(:state, :string)
      add(:scope, :string)

      add(:client_id, :uuid)
      add(:resource_owner_id, :uuid)

      timestamps()
    end

    create unique_index(:clients, [:id, :secret])
    create unique_index(:clients, [:id, :redirect_uri])
    create index("tokens", [:value])
    create unique_index("tokens", [:client_id, :value])
  end
end
