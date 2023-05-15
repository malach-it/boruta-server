defmodule BorutaAuth.Repo.Migrations.CreateKeyPairs do
  use Ecto.Migration

  def change do
    create table(:key_pairs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :public_key, :text, null: false
      add :private_key, :text, null: false
      add :is_default, :boolean

      timestamps()
    end
  end
end
