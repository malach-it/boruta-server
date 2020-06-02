defmodule Boruta.Repo.Migrations.AddSupportedGrantTypesToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add :supported_grant_types,
        {:array, :string},
        default: ["client_credentials", "password", "authorization_code", "refresh_token", "implicit"]
    end
  end
end
