defmodule Boruta.Repo.Migrations.ChangeResourceOwnerIdType do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify :resource_owner_id, :string
    end

    drop constraint("scopes_users", "scopes_users_user_id_fkey")
    rename table("scopes_users"), :user_id, to: :resource_owner_id
    alter table(:scopes_users) do
      modify :resource_owner_id, :string, from: :uuid
    end
    rename table("scopes_users"), to: table("resource_owners_scopes")
  end
end
