defmodule Boruta.Repo.Migrations.AddRevokedAtToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :revoked_at, :utc_datetime
    end
  end
end
