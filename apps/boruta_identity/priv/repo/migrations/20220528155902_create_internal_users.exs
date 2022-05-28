defmodule BorutaIdentity.Repo.Migrations.CreateInternalUsers do
  use Ecto.Migration

  def up do
    drop constraint(:users_authorized_scopes, "users_authorized_scopes_user_id_fkey")
    alter table(:users_authorized_scopes) do
      modify :user_id, :uuid
    end
    drop constraint(:users_tokens, "users_tokens_user_id_fkey")
    alter table(:users_tokens) do
      modify :user_id, :uuid
    end
    drop constraint(:consents, "consents_user_id_fkey")
    alter table(:consents) do
      modify :user_id, :uuid
    end

    rename table(:users), to: table(:internal_users)

    alter table(:internal_users) do
      remove :last_login_at
      remove :confirmed_at
    end

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :citext, null: false
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :confirmed_at, :utc_datetime_usec
      add :last_login_at, :utc_datetime_usec
      timestamps()
    end

    create index(:users, [:provider, :uid], unique: true)

    execute("DELETE FROM users_authorized_scopes")
    alter table(:users_authorized_scopes) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    execute("DELETE FROM users_tokens")
    alter table(:users_tokens) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    execute("DELETE FROM consents")
    alter table(:consents) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
  end

  def down do
    drop constraint(:users_authorized_scopes, "users_authorized_scopes_user_id_fkey")
    alter table(:users_authorized_scopes) do
      modify :user_id, :uuid
    end
    drop constraint(:users_tokens, "users_tokens_user_id_fkey")
    alter table(:users_tokens) do
      modify :user_id, :uuid
    end
    drop constraint(:consents, "consents_user_id_fkey")
    alter table(:consents) do
      modify :user_id, :uuid
    end

    drop table(:users)

    rename table(:internal_users), to: table(:users)

    alter table(:users) do
      add :last_login_at, :utc_datetime_usec
      add :confirmed_at, :utc_datetime_usec
    end

    execute("DELETE FROM users_authorized_scopes")
    alter table(:users_authorized_scopes) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    execute("DELETE FROM users_tokens")
    alter table(:users_tokens) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    execute("DELETE FROM consents")
    alter table(:consents) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end
