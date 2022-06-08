defmodule BorutaIdentity.Repo.Migrations.AddUserAuthorizedScopesScopeId do
  use Ecto.Migration

  alias Boruta.Ecto.Admin
  alias BorutaAuth.Repo

  def up do
    Repo.start_link([])

    json_scopes =
      Admin.list_scopes()
      |> Enum.map(fn %{name: name, id: id} -> %{name: name, id: id} end)
      |> Enum.map(&Jason.encode!/1)

    execute("""
    CREATE OR REPLACE FUNCTION scope_id_from_name(name varchar(255))
    RETURNS uuid AS
    $$
      DECLARE scope_id varchar(255);
      BEGIN
        SELECT scopes::jsonb ->> 'id' INTO scope_id
        FROM unnest(ARRAY['#{json_scopes |> Enum.join("', '")}']) as scopes
        WHERE scopes::jsonb ->> 'name' = $1;

        RETURN scope_id::uuid;
      END;
    $$ LANGUAGE plpgsql
    """)

    alter table(:users_authorized_scopes) do
      add(:scope_id, :uuid)
    end

    create index(:users_authorized_scopes, [:scope_id, :user_id], unique: true)
    drop index(:users_authorized_scopes, [:name, :user_id])

    execute("""
    ALTER TABLE users_authorized_scopes
      ALTER COLUMN scope_id TYPE varchar(255)
        USING scope_id_from_name(users_authorized_scopes.name)
    """)

    execute("""
    ALTER TABLE users_authorized_scopes
      ALTER COLUMN scope_id SET NOT NULL
    """)

    alter table(:users_authorized_scopes) do
      remove(:name)
    end
  end

  def down do
    Repo.start_link([])

    json_scopes =
      Admin.list_scopes()
      |> Enum.map(fn %{name: name, id: id} -> %{name: name, id: id} end)
      |> Enum.map(&Jason.encode!/1)

    execute("""
    CREATE OR REPLACE FUNCTION scope_name_from_id(id varchar(255))
    RETURNS varchar(255) AS
    $$
      DECLARE scope_name varchar(255);
      BEGIN
        SELECT scopes::jsonb ->> 'name' INTO scope_name
        FROM unnest(ARRAY['#{json_scopes |> Enum.join("', '")}']) as scopes
        WHERE scopes::jsonb ->> 'id' = $1;

        RETURN scope_name;
      END;
    $$ LANGUAGE plpgsql
    """)

    alter table(:users_authorized_scopes) do
      add(:name, :string)
    end

    drop index(:users_authorized_scopes, [:scope_id, :user_id])
    create index(:users_authorized_scopes, [:name, :user_id], unique: true)

    execute("""
    ALTER TABLE users_authorized_scopes
      ALTER COLUMN name TYPE varchar(255)
        USING scope_name_from_id(users_authorized_scopes.scope_id)
    """)

    execute("""
    ALTER TABLE users_authorized_scopes
      ALTER COLUMN name SET NOT NULL
    """)

    alter table(:users_authorized_scopes) do
      remove(:scope_id)
    end
  end
end
