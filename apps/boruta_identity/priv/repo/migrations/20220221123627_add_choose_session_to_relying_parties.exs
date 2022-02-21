defmodule BorutaIdentity.Repo.Migrations.AddChooseSessionToRelyingParties do
  use Ecto.Migration

  def change do
    alter table(:relying_parties) do
      add :choose_session, :boolean, default: true, null: false
    end
  end
end
