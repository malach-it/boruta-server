defmodule Boruta.Repo.Migrations.AddRedirectUriToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:redirect_uri, :string)
    end
  end
end
