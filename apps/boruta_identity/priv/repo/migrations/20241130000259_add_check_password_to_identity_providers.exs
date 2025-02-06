defmodule BorutaIdentity.Repo.Migrations.AddCheckPasswordToIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      add :check_password, :boolean, null: false, default: true
    end
  end
end
