defmodule BorutaIdentity.Repo.Migrations.CreateRelyingParties do
  use Ecto.Migration

  def change do
    create table(:relying_parties) do
      add :name, :string
      add :type, :string

      timestamps()
    end

  end
end
