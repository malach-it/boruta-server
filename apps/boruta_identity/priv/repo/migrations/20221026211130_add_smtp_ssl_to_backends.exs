defmodule BorutaIdentity.Repo.Migrations.AddSmtpSslToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :smtp_ssl, :boolean
    end
  end
end
