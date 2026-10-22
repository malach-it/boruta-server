defmodule BorutaIdentity.Repo.Migrations.ChangeConsentsClientIdToText do
  use Ecto.Migration

  def change do
    alter table(:consents) do
      modify :client_id, :text, from: :string
    end
  end
end
