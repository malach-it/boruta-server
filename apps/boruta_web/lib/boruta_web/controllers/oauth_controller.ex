defmodule BorutaWeb.OauthController do
  @behaviour Boruta.Oauth.Application

  use BorutaWeb, :controller

  alias Boruta.Accounts.User
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

  def authorize(%Plug.Conn{query_params: query_params} = conn, _params) do
    current_user = conn.assigns[:current_user]
    session_chosen = get_session(conn, :session_chosen)

    conn = conn
    |> store_oauth_request(query_params)

    # TODO use a preAuthorize to see if the request is valid
    case {current_user, session_chosen} do
      {%User{}, true} ->
        conn
        |> delete_session(:session_chosen)
        |> Oauth.authorize(__MODULE__)
      {%User{}, _} ->
        redirect(conn, to: Routes.choose_session_path(conn, :new))
      {_, _} ->
        redirect(conn, to: Routes.pow_session_path(conn, :new))
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
    |> delete_session(:oauth_request)
    |> redirect(external: url)
  end

  @impl Boruta.Oauth.Application
  def authorize_error(
    %Plug.Conn{} = conn,
    %Error{status: :unauthorized, error: :invalid_resource_owner}
  ) do
    conn
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

  def revoke(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.revoke(__MODULE__)
  end

  def revoke_success(%Plug.Conn{} = conn) do
    send_resp(conn, 200, "")
  end

  defp store_oauth_request(conn, params) do
    conn
    |> put_session(:oauth_request, %{
      "response_type" => params["response_type"],
      "client_id" => params["client_id"],
      "redirect_uri" => params["redirect_uri"],
      "state" => params["state"],
      "scope" => params["scope"]
    })
  end
end
