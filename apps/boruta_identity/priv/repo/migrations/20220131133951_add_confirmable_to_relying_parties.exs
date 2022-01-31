defmodule BorutaIdentity.Repo.Migrations.AddConfirmableToRelyingParties do
  use Ecto.Migration

  def change do
    alter table(:relying_parties) do
      add :confirmable, :boolean, default: false, null: false
    end
  end
end
