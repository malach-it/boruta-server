defmodule Boruta.Repo.Migrations.RemoveUserIdFromClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      remove(:user_id)
    end
  end
end
