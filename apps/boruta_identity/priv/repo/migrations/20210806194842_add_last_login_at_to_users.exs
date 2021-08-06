defmodule BorutaIdentity.Repo.Migrations.AddLastLoginAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_login_at, :utc_datetime_usec
    end
  end
end
