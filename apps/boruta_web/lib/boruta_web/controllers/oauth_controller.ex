defmodule BorutaWeb.OauthController do
  @behaviour Boruta.Oauth.Application

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.TokenResponse
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes
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

  def authorize(%Plug.Conn{query_params: query_params} = conn, _params) do
    current_user = conn.assigns[:current_user]
    session_chosen = get_session(conn, :session_chosen)

    conn = store_user_return_to(conn, query_params)

    # TODO use a preAuthorize to see if the request is valid
    case {current_user, session_chosen} do
      {%User{}, true} ->
        conn
        |> delete_session(:session_chosen)
        |> Oauth.authorize(%ResourceOwner{sub: current_user.id, username: current_user.email}, __MODULE__)
      {%User{}, _} ->
        redirect(conn, to: Routes.choose_session_path(conn, :new))
      {_, _} ->
        redirect(conn, to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
    end
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
    |> redirect(external: url)
  end

  @impl Boruta.Oauth.Application
  def authorize_error(
    %Plug.Conn{} = conn,
    %Error{status: :unauthorized, error: :invalid_resource_owner}
  ) do
    conn
    |> redirect(to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
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

  def revoke(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.revoke(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def revoke_success(%Plug.Conn{} = conn) do
    send_resp(conn, 200, "")
  end
  @impl Boruta.Oauth.Application
  def revoke_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end

  defp store_user_return_to(conn, %{"code_challenge_method" => code_challenge_method} = params) do
    conn
    |> put_session(:user_return_to, Routes.oauth_path(conn, :authorize, [
      client_id: params["client_id"],
      code_challenge: params["code_challenge"],
      code_challenge_method: code_challenge_method,
      redirect_uri: params["redirect_uri"],
      response_type: params["response_type"],
      scope: params["scope"],
      state: params["state"]
    ]))
  end
  defp store_user_return_to(conn, params) do
    conn
    |> put_session(:user_return_to, Routes.oauth_path(conn, :authorize, [
      client_id: params["client_id"],
      code_challenge: params["code_challenge"],
      redirect_uri: params["redirect_uri"],
      response_type: params["response_type"],
      scope: params["scope"],
      state: params["state"]
    ]))
  end
end
