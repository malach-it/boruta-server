defmodule BorutaIdentity.Repo.Migrations.AddBlockedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :blocked, :boolean, null: false, default: false
    end
  end
end
