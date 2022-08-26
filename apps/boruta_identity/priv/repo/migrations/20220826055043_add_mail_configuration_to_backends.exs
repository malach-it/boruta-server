defmodule BorutaIdentity.Repo.Migrations.AddMailConfigurationToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :smtp_from, :string
      add :smtp_relay, :string
      add :smtp_username, :string
      add :smtp_password, :string
      add :smtp_tls, :string
      add :smtp_port, :integer
    end
  end
end
