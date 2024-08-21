defmodule BorutaIdentity.WebauthnTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Webauthn

  describe "options/2" do
    test "returns webauthn options" do
      user = insert(:user)

      assert {:ok, %Webauthn.Options{
        user: webauthn_user,
        challenge: challenge,
        publicKeyCredParams: %{alg: -7, type: "public-key"},
        rp: %{id: "localhost"}
      }} = Webauthn.options(user, true)

      assert challenge
      assert webauthn_user[:id] == user.id
      assert webauthn_user[:displayName] == user.username
    end
  end

  @tag :skip
  test "registration"

  @tag :skip
  test "authentication"
end
