defmodule BorutaWeb.OpenidController do
  use BorutaWeb, :controller

  alias Boruta.Ecto
  alias BorutaWeb.OauthView

  def userinfo(conn, _params) do
    with %{"sub" => "" <> sub, "scope" => scope} <- conn.assigns[:introspected_token],
         userinfo <- BorutaWeb.ResourceOwners.claims(sub, scope)
         |> Map.put(:sub, sub) do
      conn
      |> put_view(OauthView)
      render("userinfo.json", userinfo: userinfo)
    else
      _ -> {:error, :not_found}
    end
  end

  def jwks_index(conn, _params) do
    with clients <- Ecto.Admin.list_clients() do
      conn
      |> put_view(OauthView)
      |> render("jwks.json", clients: clients)
    end
  end

  def jwks_show(conn, %{"client_id" => client_id}) do
    with %Ecto.Client{} = client <- Ecto.Admin.get_client!(client_id) do
      conn
      |> put_view(OauthView)
      |> render("jwk.json", client: client)
    end
  end
end
