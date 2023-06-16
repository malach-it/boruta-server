defmodule BorutaIdentity.Repo.Migrations.CreateRolesUsers do
  use Ecto.Migration

  def change do
    create table(:roles_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:roles_users, [:role_id, :user_id], unique: true)
  end
end
