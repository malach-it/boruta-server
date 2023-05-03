defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template

  # @password "hello world!"
  @hashed_password "$argon2id$v=19$m=131072,t=8,p=4$9lPv7KsJogno0FlnhaRQXA$TeTY9FYjR1HJtZzg+N1z0oDC+0Mn7buPpOMhDP+M2Ik"

  def user_factory do
    %User{
      username: "user#{System.unique_integer()}@example.com",
      uid: SecureRandom.hex(),
      backend: insert(:backend)
    }
  end

  def reset_password_user_token_factory do
    user = build(:user)

    %UserToken{
      token: SecureRandom.hex(64),
      context: "reset_password",
      sent_to: user.username,
      user: user
    }
  end

  def internal_user_factory do
    %Internal.User{
      email: "user#{System.unique_integer()}@example.com",
      hashed_password: @hashed_password,
      backend: build(:backend)
    }
  end

  def consent_factory do
    %Consent{
      client_id: SecureRandom.uuid(),
      scopes: []
    }
  end

  def client_identity_provider_factory do
    %ClientIdentityProvider{
      client_id: SecureRandom.uuid(),
      identity_provider: build(:identity_provider)
    }
  end

  def identity_provider_factory do
    %IdentityProvider{
      name: sequence(:name, &"identity provider #{&1}"),
      backend: build(:backend)
    }
  end

  def backend_factory do
    %Backend{
      name: "backend name",
      type: "Elixir.BorutaIdentity.Accounts.Internal"
    }
  end

  def federated_backend_factory do
    %Backend{
      name: "backend name",
      type: "Elixir.BorutaIdentity.Accounts.Internal",
      federated_servers: [%{
        "name" => "federated",
        "client_id" => "client_id",
        "client_secret" => "client_secret",
        "base_url" => "http://localhost:7878",
        "token_path" => "/token_path",
        "authorize_path" => "/authorize_path",
        "userinfo_path" => "/userinfo_path",
      }]
    }
  end

  def ldap_backend_factory do
    %Backend{
      name: "backend name",
      type: "Elixir.BorutaIdentity.Accounts.Ldap",
      ldap_pool_size: 2,
      ldap_host: "ldpa.test",
      ldap_user_rdn_attribute: "sn",
      ldap_base_dn: "dc=ldap,dc=test",
      ldap_ou: ""
    }
  end

  def smtp_backend_factory do
    %Backend{
      name: "backend name",
      type: "Elixir.BorutaIdentity.Accounts.Internal",
      smtp_from: "from@test.factory",
      smtp_relay: "test.smtp.factory",
      smtp_ssl: false,
      smtp_tls: "never",
      smtp_username: "factory_smtp_username",
      smtp_password: "factory_smtp_password",
      smtp_port: 25
    }
  end

  def template_factory do
    %Template{
      type: "template_type",
      content: "template content"
    }
  end

  def new_registration_template_factory do
    %Template{
      type: "new_registration",
      content: Template.default_content(:new_registration)
    }
  end

  def email_template_factory do
    %EmailTemplate{
      type: "template_type",
      txt_content: "template content",
      html_content: "template content"
    }
  end

  def reset_password_instructions_email_template_factory do
    %EmailTemplate{
      type: "reset_password_instructions",
      txt_content: EmailTemplate.default_txt_content(:reset_password_instructions),
      html_content: EmailTemplate.default_html_content(:reset_password_instructions)
    }
  end

  def error_template_factory do
    %ErrorTemplate{
      type: "400",
      content: "error template content"
    }
  end
end
