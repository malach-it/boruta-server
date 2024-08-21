defmodule BorutaIdentity.Repo.Migrations.AddWebauthnPublicKeyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :webauthn_public_key, :text
      add :webauthn_registered_at, :utc_datetime_usec
      add :webauthn_identifier, :string
    end
  end
end
