defmodule Boruta.Repo.Migrations.AddRefreshTokenToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:refresh_token, :string)
    end
  end
end
