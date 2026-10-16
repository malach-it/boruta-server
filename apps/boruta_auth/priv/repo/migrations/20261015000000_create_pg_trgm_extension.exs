defmodule BorutaAuth.Repo.Migrations.CreatePgTrgmExtension do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
  end

  def down, do: :ok
end
