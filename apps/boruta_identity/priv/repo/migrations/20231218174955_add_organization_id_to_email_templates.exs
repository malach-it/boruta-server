defmodule BorutaIdentity.Repo.Migrations.AddOrganizationIdToEmailTemplates do
  use Ecto.Migration

  def change do
    alter table(:email_templates) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all)
      modify :backend_id, :uuid, null: true
    end
  end
end
