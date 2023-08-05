defmodule BorutaIdentity.Repo.Migrations.AddTotpableToIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      add :totpable, :boolean, default: false, null: false
    end
  end
end
