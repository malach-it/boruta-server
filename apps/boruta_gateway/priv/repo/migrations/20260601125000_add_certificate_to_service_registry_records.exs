defmodule BorutaGateway.Repo.Migrations.AddCertificateToServiceRegistryRecords do
  use Ecto.Migration

  def change do
    alter table(:service_registry_records) do
      add_if_not_exists(:certificate, :text)
    end
  end
end
