defmodule BorutaIdentity.Repo.Migrations.CreateConsents do
  use Ecto.Migration

  def change do
    create table(:consents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :scopes, {:array, :string}, default: []

      timestamps()
    end

  end
end
