defmodule BorutaWeb.UserController do
  use BorutaWeb, :controller

  import BorutaWeb.Authorization, only: [
    authorize: 2
  ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  plug :authorize, ["users:manage:all"]

  action_fallback BorutaWeb.FallbackController

  def current(conn, _) do
    %{"sub" => sub, "username" => username} = conn.assigns[:introspected_token]
    user = %Accounts.User{id: sub, email: username}
    render(conn, "current.json", user: user)
  end
end
