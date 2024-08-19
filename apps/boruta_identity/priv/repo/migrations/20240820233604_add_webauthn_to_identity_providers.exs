defmodule BorutaIdentity.Repo.Migrations.AddWebauthnToIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      add :webauthnable, :boolean, default: false, null: false
      add :enforce_webauthn, :boolean, default: false, null: false
    end
  end
end
