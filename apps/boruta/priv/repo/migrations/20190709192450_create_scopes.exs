defmodule Boruta.Repo.Migrations.CreateScopes do
  use Ecto.Migration

  def change do
    create table(:scopes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :public, :boolean, default: false, null: false

      timestamps()
    end
  end
end
