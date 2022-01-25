defmodule BorutaIdentity.Repo.Migrations.UsersEmailRelyingPartyIdIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:users, [:email])

    create unique_index(:users, [:email, :relying_party_id])
  end
end
