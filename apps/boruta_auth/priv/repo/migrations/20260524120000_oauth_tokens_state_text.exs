defmodule BorutaAuth.Repo.Migrations.OauthTokensStateText do
  use Ecto.Migration

  def change do
    alter table(:oauth_tokens) do
      modify :state, :text, from: :string
    end
  end
end
