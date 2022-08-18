defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.Consent
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

  def error_template_factory do
    %ErrorTemplate{
      type: "400",
      content: "error template content"
    }
  end
end
