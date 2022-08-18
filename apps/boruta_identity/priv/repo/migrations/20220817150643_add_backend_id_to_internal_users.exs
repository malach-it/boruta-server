defmodule BorutaIdentity.Repo.Migrations.AddBackendIdToInternalUsers do
  use Ecto.Migration

  def up do
    alter table(:internal_users) do
      add :backend_id, references(:backends, type: :uuid, on_delete: :nothing)
    end

    execute("""
      UPDATE internal_users
        SET backend_id = (
          SELECT id
            FROM backends
            WHERE type = 'Elixir.BorutaIdentity.Accounts.Internal'
            LIMIT 1
        )
    """)

    create index(:internal_users, [:backend_id, :email], unique: true)

    alter table(:internal_users) do
      modify :backend_id, :uuid, null: false
    end
  end

  def down do
    alter table(:internal_users) do
      remove :backend_id
    end
  end
end
