defmodule BorutaGateway.Repo.Migrations.AddAuthorizationTypeToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:authorization_type, :string, null: false, default: "oauth_bearer")
    end
  end
end
