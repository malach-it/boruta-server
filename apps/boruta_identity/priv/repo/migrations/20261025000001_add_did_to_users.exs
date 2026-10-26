defmodule BorutaIdentity.Repo.Migrations.AddDidToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :did, :text
    end

    create unique_index(:users, [:backend_id, :did])
  end
end
