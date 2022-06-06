defmodule BorutaWeb.OpenidController do
  @behaviour Boruta.Openid.JwksApplication
  use BorutaWeb, :controller

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid
  alias BorutaWeb.OauthView

  def userinfo(conn, _params) do
    with %{"sub" => "" <> sub, "scope" => scope} <- conn.assigns[:introspected_token],
         userinfo <-
           BorutaIdentity.ResourceOwners.claims(%ResourceOwner{sub: sub}, scope)
           |> Map.put(:sub, sub) do
      conn
      |> put_view(OauthView)
      |> render("userinfo.json", userinfo: userinfo)
    else
      _ -> {:error, :not_found}
    end
  end

  def jwks_index(conn, _params) do
    Openid.jwks(conn, __MODULE__)
  end

  def jwk_list(conn, jwk_keys) do
    conn
    |> put_view(OauthView)
    |> render("jwks.json", keys: jwk_keys)
  end

  def well_known(conn, _params) do
    conn
    |> put_view(OauthView)
    |> render("well_known.json", routes: Routes)
  end
end
