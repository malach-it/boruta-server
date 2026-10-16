defmodule BorutaAuth.Repo.Migrations.AddUserDataNonceToOauthTokens do
  use Ecto.Migration

  def change do
    alter table(:oauth_tokens) do
      add(:user_data_nonce, :string)
    end
  end
end
