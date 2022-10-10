defmodule BorutaIdentity.IdentityProviders.IdentityProviderTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

  describe "template/2" do
    setup do
      identity_provider = insert(:identity_provider, templates: [])

      identity_provider_with_template =
        insert(:identity_provider,
          templates: [
            build(:new_registration_template, content: "custom new registration template")
          ]
        )

      {:ok,
       identity_provider: identity_provider,
       identity_provider_with_template: identity_provider_with_template}
    end

    test "returns nil", %{identity_provider: identity_provider} do
      assert IdentityProvider.template(identity_provider, :unexisting) == nil
    end

    test "returns default template", %{identity_provider: identity_provider} do
      assert IdentityProvider.template(identity_provider, :new_registration) ==
               %{
                 Template.default_template(:new_registration)
                 | identity_provider_id: identity_provider.id,
                   identity_provider: identity_provider
               }
    end

    test "returns identity provider template", %{
      identity_provider_with_template: identity_provider
    } do
      assert IdentityProvider.template(identity_provider, :new_registration) ==
               List.first(identity_provider.templates)
               |> Repo.preload(identity_provider: [:backend, :templates])
    end
  end

  describe "check_feature/2" do
    setup do
      identity_provider = insert(:identity_provider)

      {:ok, identity_provider: identity_provider}
    end

    test "returns an error if feature is not supported", %{identity_provider: identity_provider} do
      assert IdentityProvider.check_feature(identity_provider, :not_supported) ==
               {:error, "This provider does not support this feature."}
    end

    test "returns an error if identity provider disabled the feature", %{
      identity_provider: identity_provider
    } do
      identity_provider = %{identity_provider | authenticable: false}

      assert IdentityProvider.check_feature(identity_provider, :initialize_session) ==
               {:error, "Feature is not enabled for client identity provider."}
    end

    test "returns an error if identity provider backend does not support the feature", %{
      identity_provider: identity_provider
    } do
      identity_provider = %{
        identity_provider
        | registrable: true,
          backend: insert(:backend, type: Atom.to_string(Ldap))
      }

      assert IdentityProvider.check_feature(identity_provider, :register) ==
               {:error, "Feature is not enabled for identity provider backend implementation."}
    end

    test "returns ok if feature is supported", %{identity_provider: identity_provider} do
      assert IdentityProvider.check_feature(identity_provider, :initialize_session) ==
               :ok
    end
  end
end
