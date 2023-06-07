defmodule BorutaIdentity.Repo.Migrations.CreateRolesScopes do
  use Ecto.Migration

  def change do
    create table(:roles_scopes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :scope_id, :uuid, null: false

      timestamps()
    end

    create index(:roles_scopes, [:role_id, :scope_id], unique: true)
  end
end
