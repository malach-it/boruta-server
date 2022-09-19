defmodule BorutaIdentity.Repo.Migrations.AddLdapConfigurationToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :ldap_pool_size, :integer, default: 5
      add :ldap_host, :string
      add :ldap_password, :string
      add :ldap_base_dn, :string
      add :ldap_ou, :string
    end
  end
end
