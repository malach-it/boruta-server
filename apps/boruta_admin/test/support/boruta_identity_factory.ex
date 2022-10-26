defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
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
      backend: build(:backend)
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

  def default_backend_factory do
    %Backend{
      name: "backend name",
      type: "Elixir.BorutaIdentity.Accounts.Internal",
      is_default: true
    }
  end

  def template_factory do
    %Template{
      type: "new_registration",
      content: "new registration template content",
      identity_provider: build(:identity_provider)
    }
  end

  def error_template_factory do
    %ErrorTemplate{
      type: "400",
      content: "error template content"
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

end
