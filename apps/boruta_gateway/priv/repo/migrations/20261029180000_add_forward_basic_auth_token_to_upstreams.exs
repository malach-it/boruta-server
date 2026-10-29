defmodule BorutaGateway.Repo.Migrations.AddForwardBasicAuthTokenToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:forward_basic_auth_token, :boolean, default: false, null: false)
    end
  end
end
