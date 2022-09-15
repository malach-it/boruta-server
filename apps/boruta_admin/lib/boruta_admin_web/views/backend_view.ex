defmodule BorutaAdminWeb.BackendView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.BackendView

  def render("index.json", %{backends: backends}) do
    %{data: render_many(backends, BackendView, "backend.json")}
  end

  def render("show.json", %{backend: backend}) do
    %{data: render_one(backend, BackendView, "backend.json")}
  end

  def render("backend.json", %{backend: backend}) do
    %{
      id: backend.id,
      name: backend.name,
      type: backend.type,
      is_default: backend.is_default,
      password_hashing_alg: backend.password_hashing_alg,
      password_hashing_opts: backend.password_hashing_opts,
      ldap_pool_size: backend.ldap_pool_size,
      ldap_host: backend.ldap_host,
      ldap_user_rdn_attribute: backend.ldap_user_rdn_attribute,
      ldap_base_dn: backend.ldap_base_dn,
      ldap_ou: backend.ldap_ou,
      smtp_from: backend.smtp_from,
      smtp_relay: backend.smtp_relay,
      smtp_username: backend.smtp_username,
      smtp_password: backend.smtp_password,
      smtp_tls: backend.smtp_tls,
      smtp_port: backend.smtp_port
    }
  end
end
