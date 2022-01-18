defmodule BorutaIdentity.Repo.Migrations.AddUniqueNameToRelyingParties do
  use Ecto.Migration

  def change do
    create index(:relying_parties, [:name], unique: true)
  end
end
