defmodule BorutaWeb.Oauth.IntrospectController do
  @behaviour Boruta.Oauth.IntrospectApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse
  alias BorutaWeb.OauthView

  def introspect(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.introspect(__MODULE__)
  end

  @impl Boruta.Oauth.IntrospectApplication
  def introspect_success(conn, %IntrospectResponse{} = response) do
    conn
    |> put_view(OauthView)
    |> render("introspect.#{get_format(conn)}", response: response)
  end

  @impl Boruta.Oauth.IntrospectApplication
  def introspect_error(conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
end
