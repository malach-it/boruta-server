defmodule Boruta.Repo.Migrations.RenameTokensUserId do
  use Ecto.Migration

  def change do
    rename table(:tokens), :user_id, to: :resource_owner_id
  end
end
