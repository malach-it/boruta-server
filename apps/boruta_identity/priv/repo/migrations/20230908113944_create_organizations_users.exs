defmodule BorutaIdentity.Repo.Migrations.CreateOrganizationsUsers do
  use Ecto.Migration

  def change do
    create table(:organizations_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_id, references(:organizations, type: :uuid), null: false
      add :user_id, references(:users, type: :uuid), null: false

      timestamps()
    end

    create index(:organizations_users, [:organization_id, :user_id], unique: true)
  end
end
