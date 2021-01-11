defmodule BorutaIdentity.Repo.Migrations.CreateScopesUsers do
  use Ecto.Migration

  def change do
    create(table(:scopes_users, primary_key: false)) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :scope_id, :uuid, null: false

      timestamps()
    end

    create(unique_index(:scopes_users, [:user_id, :scope_id]))
  end
end
