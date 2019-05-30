defmodule BorutaWeb.OauthController do
  @behaviour Boruta.Oauth.Application

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias BorutaWeb.OauthView

  action_fallback BorutaWeb.FallbackController

  def token(conn, _params) do
    conn |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def token_success(conn, %Boruta.Oauth.Token{} = token) do
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

  def authorize(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.authorize(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def authorize_success(conn, %Boruta.Oauth.Token{type: "access_token"} = token) do
    {:ok, expires_at} = DateTime.from_unix(token.expires_at)
    expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

    url = "#{token.client.redirect_uri}#access_token=#{token.value}&expires_in=#{expires_in}"
    conn
    |> redirect(external: url)
  end

  def authorize_success(conn, %Boruta.Oauth.Token{type: "code", client: client, value: value}) do
    url = "#{client.redirect_uri}?code=#{value}"
    conn
    |> redirect(external: url)
  end

  @impl Boruta.Oauth.Application
  def authorize_error(
    %Plug.Conn{query_params: query_params} = conn,
    {:unauthorized, %{error: "invalid_resource_owner"}}
  ) do
    conn
    |> put_session(:oauth_request, %{
      "response_type" => query_params["response_type"],
      "client_id" => query_params["client_id"],
      "redirect_uri" => query_params["redirect_uri"]
    })
    |> redirect(to: Routes.session_path(conn, :new))
  end
  def authorize_error(conn, {_status, %{error: error, error_description: error_description, format: :query, redirect_uri: redirect_uri}}) do
    query = URI.encode_query(%{error: error, error_description: error_description})
    conn
    |> redirect(external: "#{redirect_uri}?#{query}")
  end
  def authorize_error(conn, {_status, %{error: error, error_description: error_description, format: :fragment, redirect_uri: redirect_uri}}) do
    query = URI.encode_query(%{error: error, error_description: error_description})
    conn
    |> redirect(external: "#{redirect_uri}##{query}")
  end
  def authorize_error(conn, {status, %{error: error, error_description: error_description}}) do
    conn
    |> put_status(status)
    |> put_view(BorutaWeb.OauthView)
    |> render("error." <> get_format(conn), error: error, error_description: error_description)
  end
end
