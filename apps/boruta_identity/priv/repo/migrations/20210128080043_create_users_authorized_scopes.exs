defmodule BorutaIdentity.Repo.Migrations.CreateUsersAuthorizedScopes do
  use Ecto.Migration

  def change do
    create(table(:users_authorized_scopes, primary_key: false)) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, null: false

      timestamps()
    end
  end
end
