defmodule BorutaIdentity.Repo.Migrations.CreateBackends do
  use Ecto.Migration

  def change do
    create table(:backends, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :password_hashing_alg, :string, null: false
      add :password_hashing_salt, :string, null: false, default: ""

      timestamps()
    end
  end
end
