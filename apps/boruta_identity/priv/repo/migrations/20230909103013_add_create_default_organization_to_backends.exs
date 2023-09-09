defmodule BorutaIdentity.Repo.Migrations.AddCreateDefaultOrganizationToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :create_default_organization, :boolean, null: false, default: false
    end
  end
end
