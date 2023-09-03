defmodule BorutaIdentity.Repo.Migrations.AddTotpToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :string
      add :totp_registered_at, :utc_datetime_usec
    end
  end
end
