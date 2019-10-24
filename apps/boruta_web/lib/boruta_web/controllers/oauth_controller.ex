defmodule BorutaWeb.OauthController do
  @behaviour Boruta.Oauth.Application

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse
  alias Boruta.Oauth.TokenResponse
  alias BorutaWeb.OauthView

  action_fallback BorutaWeb.FallbackController

  def introspect(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.introspect(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def introspect_success(conn, %IntrospectResponse{} = response) do
    conn
    |> put_view(OauthView)
    |> render("introspect.json", response: response)
  end

  @impl Boruta.Oauth.Application
  def introspect_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end

  def token(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def token_success(conn, %TokenResponse{} = response) do
    conn
    |> put_view(OauthView)
    |> render("token.json", response: response)
  end

  @impl Boruta.Oauth.Application
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end

  def authorize(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.authorize(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def authorize_success(
    conn,
    %AuthorizeResponse{
      type: type,
      redirect_uri: redirect_uri,
      value: value,
      expires_in: expires_in,
      state: state
    }
  ) do
    query = case {type, state} do
      {"access_token", nil} -> URI.encode_query(%{access_token: value, expires_in: expires_in})
      {"access_token", state} -> URI.encode_query(%{access_token: value, expires_in: expires_in, state: state})
      {"code", nil} -> URI.encode_query(%{code: value})
      {"code", state} -> URI.encode_query(%{code: value, state: state})
    end
    url = case type do
      "access_token" -> "#{redirect_uri}##{query}"
      "code" -> "#{redirect_uri}?#{query}"
    end
    conn
    |> delete_session(:oauth_request)
    |> redirect(external: url)
  end

  @impl Boruta.Oauth.Application
  def authorize_error(
    %Plug.Conn{query_params: query_params} = conn,
    %Error{status: :unauthorized, error: :invalid_resource_owner}
  ) do
    conn
    |> put_session(:oauth_request, %{
      "response_type" => query_params["response_type"],
      "client_id" => query_params["client_id"],
      "redirect_uri" => query_params["redirect_uri"],
      "state" => query_params["state"],
      "scope" => query_params["scope"]
    })
    |> redirect(to: Routes.pow_session_path(conn, :new))
  end
  def authorize_error(
    conn,
    %Error{
      error: error,
      error_description: error_description,
      format: format,
      redirect_uri: redirect_uri
    }
  ) when not is_nil(format) do
    query = URI.encode_query(%{error: error, error_description: error_description})
    url = case format do
      :query -> "#{redirect_uri}?#{query}"
      :fragment -> "#{redirect_uri}##{query}"
    end
    conn
    |> redirect(external: url)
  end
  def authorize_error(
    conn,
    %Error{status: status, error: error, error_description: error_description}
  ) do
    conn
    |> put_status(status)
    |> put_view(BorutaWeb.OauthView)
    |> render("error." <> get_format(conn), error: error, error_description: error_description)
  end
end
