defmodule BorutaIdentity.IdentityProviders.IdentityProviderTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

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
       identity_provider: identity_provider, identity_provider_with_template: identity_provider_with_template}
    end

    test "returns nil", %{identity_provider: identity_provider} do
      assert IdentityProvider.template(identity_provider, :unexisting) == nil
    end

    test "returns default template", %{identity_provider: identity_provider} do
      assert IdentityProvider.template(identity_provider, :new_registration) ==
        %{Template.default_template(:new_registration)|identity_provider_id: identity_provider.id, identity_provider: identity_provider}
    end

    test "returns identity provider template", %{identity_provider_with_template: identity_provider} do
      assert IdentityProvider.template(identity_provider, :new_registration) ==
        List.first(identity_provider.templates) |> Repo.preload(identity_provider: :templates)
    end
  end
end
