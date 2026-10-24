defmodule BorutaIdentity.Repo.Migrations.AddRequestModeToIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      add :request_mode, :string, null: false, default: "stateless"
    end

    create constraint(:identity_providers, :identity_providers_request_mode_check,
             check: "request_mode IN ('stateful', 'stateless')"
           )
  end
end
