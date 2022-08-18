defmodule BorutaIdentity.Repo.Migrations.ChangeUsersProviderToBackendId do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :provider, :string
      add :backend_id, references(:backends, type: :uuid, on_delete: :nothing)
    end

    execute("""
      UPDATE users
        SET backend_id = (
          SELECT id
            FROM backends
            WHERE type = 'Elixir.BorutaIdentity.Accounts.Internal'
            LIMIT 1
        )
    """)

    create index(:users, [:backend_id, :uid], unique: true)

    alter table(:users) do
      modify :backend_id, :uuid, null: false
    end
  end

  def down do
    alter table(:users) do
      add :provider, :string, default: "Elixir.BorutaIdentity.Accounts.Internal"
      remove :backend_id
    end

    create index(:users, [:provider, :uid], unique: true)
  end
end
