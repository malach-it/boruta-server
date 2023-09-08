defmodule BorutaIdentity.Repo.Migrations.AddLabelToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :label, :string
    end
  end
end
