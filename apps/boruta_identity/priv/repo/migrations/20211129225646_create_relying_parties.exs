defmodule BorutaIdentity.Repo.Migrations.CreateRelyingParties do
  use Ecto.Migration

  def change do
    create table(:relying_parties, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :type, :string

      timestamps()
    end

  end
end
