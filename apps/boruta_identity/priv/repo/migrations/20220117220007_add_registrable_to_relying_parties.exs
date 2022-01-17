defmodule BorutaIdentity.Repo.Migrations.AddRegistrableToRelyingParties do
  use Ecto.Migration

  def change do
    alter table(:relying_parties) do
      add :registrable, :boolean, null: false, default: false
    end
  end
end
