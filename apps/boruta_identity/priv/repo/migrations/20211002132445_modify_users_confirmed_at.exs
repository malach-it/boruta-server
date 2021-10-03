defmodule BorutaIdentity.Repo.Migrations.ModifyUsersConfirmedAt do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :confirmed_at, :utc_datetime_usec
    end
  end
end
