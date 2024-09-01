defmodule BorutaAdmin.Repo.Migrations.CreateConfigurations do
  use Ecto.Migration

  def change do
    create table(:configurations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :value, :text, null: false

      timestamps()
    end

    create index(:configurations, [:name], unique: true)
  end
end
