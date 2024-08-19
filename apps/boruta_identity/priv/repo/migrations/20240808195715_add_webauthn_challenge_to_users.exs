defmodule BorutaIdentity.Repo.Migrations.AddWebauthnChallengeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :webauthn_challenge, :string
    end
  end
end
