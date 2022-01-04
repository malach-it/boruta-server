defmodule BorutaIdentity.Accounts.DeliveriesTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end

      {:ok, token} =
        Deliveries.deliver_user_reset_password_instructions(user, reset_password_url_fun)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end
end
