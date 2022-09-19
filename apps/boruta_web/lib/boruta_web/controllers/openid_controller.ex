defmodule BorutaWeb.OpenidController do
  @behaviour Boruta.Openid.JwksApplication
  @behaviour Boruta.Openid.UserinfoApplication

  use BorutaWeb, :controller

  alias Boruta.Openid
  alias BorutaWeb.OauthView

  def userinfo(conn, _params) do
    Openid.userinfo(conn, __MODULE__)
  end

  @impl Boruta.Openid.UserinfoApplication
  def userinfo_fetched(conn, userinfo) do
    conn
    |> put_view(OauthView)
    |> render("userinfo.json", userinfo: userinfo)
  end

  @impl Boruta.Openid.UserinfoApplication
  def unauthorized(conn, error) do
    conn
    |> put_resp_header(
      "www-authenticate",
      "error=\"#{error.error}\", error_description=\"#{error.error_description}\""
    )
    |> send_resp(:unauthorized, "")
  end

  def jwks_index(conn, _params) do
    Openid.jwks(conn, __MODULE__)
  end

  @impl Boruta.Openid.JwksApplication
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
