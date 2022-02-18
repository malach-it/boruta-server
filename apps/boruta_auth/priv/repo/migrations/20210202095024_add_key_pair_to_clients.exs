defmodule Boruta.Repo.Migrations.AddKeyPairToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add :public_key, :text, null: false
      add :private_key, :text, null: false
    end
  end
end
