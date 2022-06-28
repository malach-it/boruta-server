defmodule BorutaAuth.Repo.Migrations.CreateErrorTemplates do
  use Ecto.Migration

  def change do
    create table(:error_templates, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string, null: false)
      add(:content, :text, null: false)

      timestamps()
    end

    create index(:error_templates, [:type], unique: true)
  end
end
