defmodule BorutaIdentity.Repo.Migrations.AddRevokedAtToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :revoked_at, :utc_datetime_usec
    end
  end
end
