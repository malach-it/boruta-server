defmodule BorutaIdentity.Repo.Migrations.AddUserEditableToRelyingParties do
  use Ecto.Migration

  def change do
    alter table(:relying_parties) do
      add :user_editable, :boolean, default: false, null: false
    end
  end
end
