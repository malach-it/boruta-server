defmodule BorutaIdentity.Repo.Migrations.AddDidToInternalUsers do
  use Ecto.Migration

  def change do
    alter table(:internal_users) do
      add :did, :text
    end
  end
end
