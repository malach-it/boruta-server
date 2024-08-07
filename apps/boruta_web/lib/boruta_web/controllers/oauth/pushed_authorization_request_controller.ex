defmodule BorutaWeb.Oauth.PushedAuthorizationRequestController do
  @behaviour Boruta.Oauth.PushedAuthorizationRequestApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias BorutaWeb.OauthView

  def pushed_authorization_request(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.pushed_authorization_request(__MODULE__)
  end

  @impl Boruta.Oauth.PushedAuthorizationRequestApplication
  def request_stored(conn, response) do
    conn
    |> put_view(OauthView)
    |> put_status(:created)
    |> render("pushed_authorization_request.json", response: response)
  end

  @impl Boruta.Oauth.PushedAuthorizationRequestApplication
  def pushed_authorization_error(conn, %Error{
    status: status,
    error: error,
    error_description: error_description
  }) do
    conn
    |> put_view(OauthView)
    |> put_status(status)
    |> render("error.json", error: error, error_description: error_description)
  end
end
