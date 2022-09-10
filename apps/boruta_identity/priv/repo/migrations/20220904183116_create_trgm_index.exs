defmodule BorutaIdentity.Repo.Migrations.CreateTrgmIndex do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX username_trgm_idx ON users USING GIN (username gin_trgm_ops)")
  end

  def down do
    execute("DROP INDEX username_trgm_idx")
  end
end
