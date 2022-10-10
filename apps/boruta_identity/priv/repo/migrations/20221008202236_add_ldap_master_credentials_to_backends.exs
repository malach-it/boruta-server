defmodule BorutaIdentity.Repo.Migrations.AddLdapMasterCredentialsToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :ldap_master_dn, :string
      add :ldap_master_password, :string
    end
  end
end
