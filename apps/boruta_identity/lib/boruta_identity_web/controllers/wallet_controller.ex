defmodule BorutaIdentityWeb.WalletController do
  use BorutaIdentityWeb, :controller

  def index(conn, _params) do
    current_user = conn.assigns[:current_user]

    conn
    |> put_layout(false)
    |> render("index.html", code_verifier: current_user.code_verifier)
  end
end
