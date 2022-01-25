defmodule BorutaIdentity.Repo.Migrations.AddRelyingPartyIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :relying_party_id, references(:relying_parties, type: :uuid, on_delete: :delete_all)
    end
  end
end
