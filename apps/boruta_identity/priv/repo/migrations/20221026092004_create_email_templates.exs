defmodule BorutaIdentity.Repo.Migrations.CreateEmailTemplates do
  use Ecto.Migration

  def change do
    create table(:email_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :type, :string, null: false
      add :txt_content, :text, default: ""
      add :html_content, :text, default: ""

      add :backend_id, references(:backends, type: :uuid, on_delete: :delete_all), null: false
      timestamps()
    end

    create index(:email_templates, [:backend_id, :type], unique: true)
  end
end
