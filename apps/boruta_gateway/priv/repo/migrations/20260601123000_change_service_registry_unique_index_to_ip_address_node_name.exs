defmodule BorutaGateway.Repo.Migrations.ChangeServiceRegistryUniqueIndexToIpAddressNodeName do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:service_registry_records, [:ip_address]))
    drop_if_exists(unique_index(:service_registry_records, [:ip_address, :aliases]))
    create_if_not_exists(unique_index(:service_registry_records, [:ip_address, :node_name]))
  end
end
