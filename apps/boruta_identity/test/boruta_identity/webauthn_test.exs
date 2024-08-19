defmodule BorutaIdentity.WebauthnTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Webauthn

  describe "options/1" do
    test "returns webauthn options" do
      user = insert(:user)

      assert {:ok, %Webauthn.Options{
        user: webauthn_user,
        challenge: challenge,
        publicKeyCredParams: %{alg: -7, type: "public-key"},
        rp: %{id: "https://oauth.boruta.patatoid.fr"}
      }} = Webauthn.options(user)

      assert challenge
      assert webauthn_user[:id] == user.id
      assert webauthn_user[:displayName] == user.username
    end
  end
end
