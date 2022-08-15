defmodule BorutaIdentity.Repo.Migrations.RemoveTypeFromIdentityProviders do
  use Ecto.Migration

  def change do
    alter table(:identity_providers) do
      remove :type, :string, null: false
    end
  end
end
