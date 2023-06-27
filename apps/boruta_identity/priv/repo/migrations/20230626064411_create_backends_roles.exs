defmodule BorutaIdentity.Repo.Migrations.CreateBackendsRoles do
  use Ecto.Migration

  def change do
    create table(:backends_roles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :backend_id, references(:backends, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:backends_roles, [:backend_id, :role_id], unique: true)
  end
end
