defmodule BorutaIdentity.Repo.Migrations.AddLdapSerRdnAttributeToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      remove :ldap_password, :string
      add :ldap_user_rdn_attribute, :string
    end
  end
end
