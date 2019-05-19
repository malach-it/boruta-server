defmodule BorutaWeb.OauthController do
  use BorutaWeb, :controller

  alias BorutaWeb.OauthValidationPlug
  alias BorutaWeb.OauthSchema
  alias BorutaWeb.OauthView
  alias Authable.Model.Token

  plug OauthValidationPlug, OauthSchema

  action_fallback BorutaWeb.FallbackController

  def token(conn, params) do
    with %Token{} = token <- Authable.OAuth2.authorize(%{
      "grant_type" => "client_credentials",
      "client_id" => params["client_id"],
      "client_secret" => params["client_secret"],
      "scope" => params["scope"] || "" # TODO make it optional in Authable
    }) do
      conn
      |> put_view(OauthView)
      |> render("token.json", token: token)
    end
  end

  def authorize(%Plug.Conn{} = conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_session(:oauth_request, %{
          "response_type" => params["response_type"],
          "client_id" => params["client_id"],
          "redirect_uri" => params["redirect_uri"],
          "scope" => params["scope"],
          "state" => params["state"]
        })
        |> redirect(to: Routes.session_path(conn, :new))
      user ->
        with %Token{} = token <- Authable.OAuth2.authorize(%{
          "grant_type" => "implicit",
          "user" => user,
          "client_id" => params["client_id"],
          "redirect_uri" => params["redirect_uri"],
          "scope" => params["scope"]
        }) do
          {:ok, expires_at} = DateTime.from_unix(token.expires_at)
          expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

          url = "#{params["redirect_uri"]}#access_token=#{token.value}&expires_in=#{expires_in}&state=#{params["state"]}"
          conn
          |> redirect(external: url)
        end
    end
  end
end
