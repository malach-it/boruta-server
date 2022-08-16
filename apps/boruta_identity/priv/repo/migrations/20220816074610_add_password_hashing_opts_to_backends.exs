defmodule BorutaIdentity.Repo.Migrations.AddPasswordHashingOptsToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      remove :password_hashing_salt, :string
      add :password_hashing_opts, :map, default: %{}
    end
  end
end
