defmodule BorutaIdentity.Repo.Migrations.AddGroupToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :group, :string
    end
  end
end
