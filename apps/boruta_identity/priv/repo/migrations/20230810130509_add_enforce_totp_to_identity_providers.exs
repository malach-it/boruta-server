defmodule BorutaIdentity.Repo.Migrations.AddEnforceTotpToIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      add :enforce_totp, :boolean, default: false, null: false
    end
  end
end
