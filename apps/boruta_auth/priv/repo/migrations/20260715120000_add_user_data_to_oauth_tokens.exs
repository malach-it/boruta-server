defmodule BorutaAuth.Repo.Migrations.AddUserDataToOauthTokens do
  use Ecto.Migration

  def change do
    alter table(:oauth_tokens) do
      add(:user_data, :map)
    end
  end
end
