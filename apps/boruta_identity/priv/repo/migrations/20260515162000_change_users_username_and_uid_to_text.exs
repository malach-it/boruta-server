defmodule BorutaIdentity.Repo.Migrations.ChangeUsersUsernameAndUidToText do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE users
      ALTER COLUMN username TYPE text USING username::text,
      ALTER COLUMN uid TYPE text USING uid::text
    """)
  end

  def down do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    execute("""
    ALTER TABLE users
      ALTER COLUMN username TYPE citext USING username::citext,
      ALTER COLUMN uid TYPE varchar(255) USING uid::varchar(255)
    """)
  end
end
