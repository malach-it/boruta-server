defmodule BorutaWeb.Oauth.TokenController do
  @behaviour Boruta.Oauth.TokenApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse
  alias BorutaWeb.OauthView

  def token(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_success(conn, %TokenResponse{} = response) do
    # TODO get client_id and grant_type from response
    :telemetry.execute(
      [:authorization, :token, :success],
      %{},
      %{
        access_token: response.access_token,
        token_type: response.token_type,
        expires_in: response.expires_in,
        refresh_token: response.refresh_token
      }
    )

    conn
    |> put_view(OauthView)
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("cache-control", "no-store")
    |> render("token.json", response: response)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    # TODO get client_id and grant_type from error
    :telemetry.execute(
      [:authorization, :token, :failure],
      %{},
      %{
        status: status,
        error: error,
        error_description: error_description
      }
    )

    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
end
