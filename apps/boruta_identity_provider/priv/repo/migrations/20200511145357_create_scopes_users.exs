defmodule BorutaIdentityProvider.Repo.Migrations.CreateScopesUsers do
  use Ecto.Migration

  def change do
    create(table(:scopes_users, primary_key: false)) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :scope_id, :uuid, null: false

      timestamps()
    end

    create(unique_index(:scopes_users, [:user_id, :scope_id]))
  end
end
