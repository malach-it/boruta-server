defmodule BorutaIdentity.RelyingParties.RelyingPartyTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.RelyingParties.Template

  describe "template/2" do
    setup do
      relying_party = insert(:relying_party)

      relying_party_with_template =
        insert(:relying_party,
          templates: [
            build(:new_registration_template, content: "custom new registration template")
          ]
        )

      {:ok,
       relying_party: relying_party, relying_party_with_template: relying_party_with_template}
    end

    test "returns nil", %{relying_party: relying_party} do
      assert RelyingParty.template(relying_party, :unexisting) == nil
    end

    test "returns default template", %{relying_party: relying_party} do
      assert RelyingParty.template(relying_party, :new_registration) ==
        %{Template.default_template(:new_registration)|relying_party_id: relying_party.id}
    end

    test "returns relying party template", %{relying_party_with_template: relying_party} do
      assert RelyingParty.template(relying_party, :new_registration) ==
        List.first(relying_party.templates)
    end
  end
end
