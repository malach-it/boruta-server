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
  def introspect_success(%Plug.Conn{body_params: body_params} = conn, %IntrospectResponse{} = response) do
    # TODO get token from response
    token = body_params["token"]

    :telemetry.execute(
      [:authorization, :introspect, :success],
      %{},
      %{
        active: response.active,
        client_id: response.client_id,
        sub: response.sub,
        token: token
      }
    )

    conn
    |> put_view(OauthView)
    |> render("introspect.#{get_format(conn)}", response: response)
  end

  @impl Boruta.Oauth.IntrospectApplication
  def introspect_error(%Plug.Conn{body_params: body_params} = conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    # TODO get client_id and token from error
    token = body_params["token"]

    :telemetry.execute(
      [:authorization, :introspect, :failure],
      %{},
      %{
        status: status,
        error: error,
        error_description: error_description,
        token: token
      }
    )

    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
end
