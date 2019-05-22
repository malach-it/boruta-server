defmodule BorutaWeb.OauthController do
  @behaviour Boruta.Oauth.Application

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias BorutaWeb.OauthValidationPlug
  alias BorutaWeb.OauthSchema
  alias BorutaWeb.OauthView
  alias Authable.Model.Token
  alias BorutaWeb.OauthSchema

  plug OauthValidationPlug, OauthSchema when action in [:authorize]

  action_fallback BorutaWeb.FallbackController

  def token(conn, _params) do
    conn
    |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def token_success(conn, %Token{} = token) do
    conn
    |> put_view(OauthView)
    |> render("token.json", token: token)
  end

  @impl Boruta.Oauth.Application
  def token_error(conn, {status, %{error: error, error_description: error_description}}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
  # TODO remove after Authable refactor
  def token_error(conn, {:error, %{invalid_client: error_description}, status}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: "invalid_client", error_description: error_description)
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
