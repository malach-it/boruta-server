defmodule BorutaWeb.Oauth.RevokeController do
  @behaviour Boruta.Oauth.RevokeApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias BorutaWeb.OauthView

  def revoke(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.revoke(__MODULE__)
  end

  @impl Boruta.Oauth.RevokeApplication
  def revoke_success(%Plug.Conn{} = conn, token) do
    :telemetry.execute(
      [:authorization, :revoke, :success],
      %{},
      %{
        sub: token && token.sub
      }
    )

    send_resp(conn, 200, "")
  end

  @impl Boruta.Oauth.RevokeApplication
  def revoke_error(%Plug.Conn{} = conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    :telemetry.execute(
      [:authorization, :revoke, :failure],
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
