defmodule BorutaIdentity.Repo.Migrations.OrganizationsUsersReference do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE organizations_users DROP CONSTRAINT organizations_users_organization_id_fkey"
    execute "ALTER TABLE organizations_users DROP CONSTRAINT organizations_users_user_id_fkey"

    alter table(:organizations_users, primary_key: false) do
      modify :organization_id, references(:organizations, type: :uuid, on_delete: :nothing), null: false
      modify :user_id, references(:users, type: :uuid, on_delete: :nothing), null: false
    end
  end

  def down do
    execute "ALTER TABLE organizations_users DROP CONSTRATAINT organizations_users_organization_id_fkey"
    execute "ALTER TABLE organizations_users DROP CONSTRATAINT organizations_users_user_id_fkey"

    alter table(:organizations_users, primary_key: false) do
      modify :organization_id, references(:organizations, type: :uuid), null: false
      modify :user_id, references(:users, type: :uuid), null: false
    end
  end
end
