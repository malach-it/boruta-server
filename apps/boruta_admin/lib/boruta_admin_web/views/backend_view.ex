defmodule BorutaAdminWeb.BackendView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.BackendView
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend

  def render("index.json", %{backends: backends}) do
    %{data: render_many(backends, BackendView, "backend.json")}
  end

  def render("show.json", %{backend: backend}) do
    %{data: render_one(backend, BackendView, "backend.json")}
  end

  def render("show_email_template.json", %{email_template: template}) do
    %{data: render_one(template, __MODULE__, "email_template.json", template: template)}
  end

  def render("backend.json", %{backend: backend}) do
    %{
      id: backend.id,
      name: backend.name,
      type: backend.type,
      is_default: backend.is_default,
      create_default_organization: backend.create_default_organization,
      roles: IdentityProviders.get_backend_roles(backend.id),
      metadata_fields: backend.metadata_fields,
      federated_servers: backend.federated_servers,
      verifiable_credentials: backend.verifiable_credentials,
      verifiable_presentations: backend.verifiable_presentations,
      password_hashing_alg: backend.password_hashing_alg,
      password_hashing_opts: backend.password_hashing_opts,
      ldap_pool_size: backend.ldap_pool_size,
      ldap_host: backend.ldap_host,
      ldap_user_rdn_attribute: backend.ldap_user_rdn_attribute,
      ldap_base_dn: backend.ldap_base_dn,
      ldap_ou: backend.ldap_ou,
      ldap_master_dn: backend.ldap_master_dn,
      ldap_master_password: backend.ldap_master_password,
      smtp_from: backend.smtp_from,
      smtp_relay: backend.smtp_relay,
      smtp_username: backend.smtp_username,
      smtp_password: backend.smtp_password,
      smtp_ssl: backend.smtp_ssl,
      smtp_tls: backend.smtp_tls,
      smtp_port: backend.smtp_port,
      features: Backend.features(backend)
    }
  end

  def render("email_template.json", %{template: template}) do
    %{
      id: template.id,
      txt_content: template.txt_content,
      html_content: template.html_content,
      type: template.type,
      backend_id: template.backend_id
    }
  end
end
