defmodule BorutaIdentityWeb.ConsentController do
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [after_sign_in_path: 1]

  alias BorutaIdentity.Accounts

  action_fallback(BorutaIdentityWeb.FallbackController)

  def consent(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, _user} <- Accounts.consent(current_user, params) do
      redirect(conn, to: after_sign_in_path(conn))
    end
  end
end
