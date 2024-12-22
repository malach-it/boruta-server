defmodule BorutaAuth.Repo.Migrations.ChangeOauthClientsDid do
  use Ecto.Migration

  def change do
    alter table(:oauth_clients) do
      modify :did, :text
    end
  end
end
