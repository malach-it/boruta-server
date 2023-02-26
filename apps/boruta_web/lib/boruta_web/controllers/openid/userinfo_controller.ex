defmodule BorutaWeb.Openid.UserinfoController do
  @behaviour Boruta.Openid.UserinfoApplication

  use BorutaWeb, :controller

  alias Boruta.Openid
  alias Boruta.Openid.UserinfoResponse
  alias BorutaWeb.OpenidView

  def userinfo(conn, _params) do
    Openid.userinfo(conn, __MODULE__)
  end

  @impl Boruta.Openid.UserinfoApplication
  def userinfo_fetched(conn, response) do
    conn
    |> put_view(OpenidView)
    |> put_resp_header("content-type", UserinfoResponse.content_type(response))
    |> render("userinfo.#{response.format}", response: response)
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
end
