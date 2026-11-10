defmodule BorutaGateway.Repo.Migrations.AddOauthSessionWalletUriToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:oauth_session_wallet_uri, :string)
    end
  end
end
