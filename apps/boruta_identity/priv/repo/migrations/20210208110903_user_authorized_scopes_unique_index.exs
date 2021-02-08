defmodule BorutaIdentity.Repo.Migrations.UserAuthorizedScopesUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index(:users_authorized_scopes, [:name, :user_id])
  end
end
