defmodule Boruta.Repo.Migrations.UsersScopesAssociation do
  use Ecto.Migration

  def change do
    create table(:scopes_users) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:scope_id, references(:scopes, type: :uuid, on_delete: :delete_all))
    end
  end
end
