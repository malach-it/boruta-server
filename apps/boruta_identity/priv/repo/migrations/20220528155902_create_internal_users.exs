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

    execute("CREATE TABLE users as (SELECT * FROM internal_users)")

    alter table(:users, primary_key: false) do
      modify :id, :uuid, primary_key: true
      add :provider, :string
      add :uid, :string
      remove :hashed_password
    end

    execute("""
    ALTER TABLE users
      ALTER COLUMN provider TYPE varchar(255)
        USING '#{to_string(BorutaIdentity.Accounts.Internal)}'
    """)
    execute("""
    ALTER TABLE users
      ALTER COLUMN provider SET NOT NULL
    """)
    execute("""
    ALTER TABLE users
      ALTER COLUMN uid TYPE varchar(255)
        USING (users.id::varchar)
    """)
    execute("""
    ALTER TABLE users
      ALTER COLUMN uid SET NOT NULL
    """)

    rename table(:users), :email, to: :username

    alter table(:internal_users) do
      remove :last_login_at
      remove :confirmed_at
    end

    create index(:users, [:provider, :uid], unique: true)

    alter table(:users_authorized_scopes) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    alter table(:users_tokens) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
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

    drop index(:users, [:provider, :uid], unique: true)

    alter table(:users, primary_key: false) do
      add :hashed_password, :string
    end

    execute("""
    CREATE OR REPLACE FUNCTION hashed_password(uid varchar(255))
    RETURNS varchar(255) AS
    $$
      DECLARE hp varchar(255);
      BEGIN
        SELECT hashed_password INTO hp
        FROM internal_users
        WHERE id = $1::uuid;

        RETURN hp;
      END;
    $$ LANGUAGE plpgsql
    """)
    execute("""
    ALTER TABLE users
      ALTER COLUMN hashed_password TYPE varchar(255)
        USING hashed_password(users.uid)
    """)
    execute("""
    ALTER TABLE users
      ALTER COLUMN hashed_password SET NOT NULL
    """)

    alter table(:users, primary_key: false) do
      remove :provider
      remove :uid
    end

    drop table(:internal_users)

    rename table(:users), :username, to: :email

    alter table(:users_authorized_scopes) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    alter table(:users_tokens) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
    alter table(:consents) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end
