defmodule BorutaGateway.Repo.Migrations.AddForwardedTokenKeyPairToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :forwarded_token_public_key, :text
      add :forwarded_token_private_key, :text
    end
  end
end
