defmodule BorutaIdentity.Repo.Migrations.AddBackendIdToIdentityProviders do
  use Ecto.Migration

  def up do
    backend_id = SecureRandom.uuid()
    now = DateTime.utc_now()
    execute("""
    INSERT INTO backends (id, type, name, password_hashing_alg, inserted_at, updated_at)
      VALUES ('#{backend_id}', 'Elixir.BorutaIdentity.Accounts.Internal', 'Default', 'argon2', '#{DateTime.to_iso8601(now)}', '#{DateTime.to_iso8601(now)}')
    """)

    alter table(:identity_providers) do
      add :backend_id, references(:backends, type: :binary_id, on_delete: :nothing)
    end
    execute("""
    UPDATE identity_providers
      SET backend_id = '#{backend_id}'
    """)
    alter table(:identity_providers) do
      modify :backend_id, :binary_id, null: false
    end
  end

  def down do
    alter table(:identity_providers) do
      remove :backend_id, references(:backends, type: :binary_id, on_delete: :nothing), null: false
    end
  end
end
