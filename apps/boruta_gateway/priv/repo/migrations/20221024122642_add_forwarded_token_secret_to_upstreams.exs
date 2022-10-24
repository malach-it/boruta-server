defmodule BorutaGateway.Repo.Migrations.AddForwardedTokenSecretToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :forwarded_token_secret, :string
    end
  end
end
