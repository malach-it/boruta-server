defmodule BorutaIdentity.Accounts.DeliveriesTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts.Deliveries

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      {:ok, user: user_fixture(%{backend: insert(:smtp_backend)})}
    end

    test "sends token through notification", %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end

      assert {:ok, _email} =
               Deliveries.deliver_user_reset_password_instructions(
                 user.backend,
                 user,
                 reset_password_url_fun
               )
    end
  end
end
