defmodule BorutaIdentity.Repo.Migrations.AddNameToScopesUsers do
  use Ecto.Migration

  def change do
    alter table(:scopes_users) do
      add :name, :string, null: false
      remove :scope_id, :uuid
    end
  end
end
