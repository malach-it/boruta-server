defmodule BorutaWeb.Oauth.AuthorizeController do
  @dialyzer :no_match
  @behaviour Boruta.Oauth.AuthorizeApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes
  alias BorutaWeb.OauthView

  def authorize(%Plug.Conn{query_params: query_params} = conn, _params) do
    current_user = conn.assigns[:current_user]
    session_chosen = get_session(conn, :session_chosen) || false

    conn = store_user_return_to(conn, query_params)

    authorize_response(
      conn,
      current_user,
      session_chosen,
      Accounts.consented?(current_user, conn),
      query_params["prompt"]
    )
  end

  defp authorize_response(conn, current_user, _, _, "none") do
    resource_owner =
      current_user && %ResourceOwner{sub: current_user.id, username: current_user.email}

    conn
    |> delete_session(:session_chosen)
    |> Oauth.authorize(
      resource_owner,
      __MODULE__
    )
  end

  defp authorize_response(conn, %User{} = current_user, true, false, _) do
    conn
    |> Oauth.preauthorize(
      %ResourceOwner{sub: current_user.id, username: current_user.email},
      __MODULE__
    )
  end

  defp authorize_response(conn, %User{} = current_user, true, true, _) do
    conn
    |> delete_session(:session_chosen)
    |> Oauth.authorize(
      %ResourceOwner{sub: current_user.id, username: current_user.email},
      __MODULE__
    )
  end

  defp authorize_response(conn, %User{}, _, _, _) do
    # TODO a render can be a better choice
    redirect(conn, to: Routes.choose_session_path(conn, :new))
  end

  defp authorize_response(conn, _, _, _, _) do
    redirect(conn, to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(conn, %AuthorizationSuccess{client: client, scope: scope}) do
    scopes = String.split(scope, " ")
    conn
    |> put_view(OauthView)
    |> render("preauthorize.html", client: client, scopes: scopes)
  end

  @impl Boruta.Oauth.AuthorizeApplication
  defdelegate preauthorize_error(conn, error), to: __MODULE__, as: :authorize_error

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(
        conn,
        %AuthorizeResponse{
          type: type,
          redirect_uri: redirect_uri,
          access_token: access_token,
          code: code,
          id_token: id_token,
          expires_in: expires_in,
          state: state,
          token_type: token_type
        }
      ) do
    query =
      %{
        code: code,
        id_token: id_token,
        access_token: access_token,
        expires_in: expires_in,
        state: state,
        token_type: token_type
      }
      |> Enum.map(fn {param_type, value} ->
        value && {param_type, value}
      end)
      |> Enum.reject(&is_nil/1)
      |> URI.encode_query()

    url =
      case type do
        :token -> "#{redirect_uri}##{query}"
        :hybrid -> "#{redirect_uri}##{query}"
        :code -> "#{redirect_uri}?#{query}"
      end

    conn
    |> redirect(external: url)
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(
        %Plug.Conn{query_params: query_params} = conn,
        %Error{status: :unauthorized, error: :invalid_resource_owner} = error
      ) do
    case query_params["prompt"] do
      "none" ->
        authorize_error(conn, %{
          error
          | error: :login_required,
            format: :fragment,
            redirect_uri: query_params["redirect_uri"]
        })

      _ ->
        conn
        |> redirect(to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
    end
  end

  def authorize_error(conn, %Error{format: format} = error)
      when not is_nil(format) do
    conn
    |> redirect(external: Error.redirect_to_url(error))
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

  defp store_user_return_to(conn, %{"code_challenge_method" => code_challenge_method} = params) do
    conn
    |> put_session(
      :user_return_to,
      Routes.authorize_path(conn, :authorize,
        client_id: params["client_id"],
        code_challenge: params["code_challenge"],
        nonce: params["nonce"],
        code_challenge_method: code_challenge_method,
        redirect_uri: params["redirect_uri"],
        response_type: params["response_type"],
        scope: params["scope"],
        state: params["state"]
      )
    )
  end

  defp store_user_return_to(conn, params) do
    conn
    |> put_session(
      :user_return_to,
      Routes.authorize_path(conn, :authorize,
        client_id: params["client_id"],
        code_challenge: params["code_challenge"],
        nonce: params["nonce"],
        redirect_uri: params["redirect_uri"],
        response_type: params["response_type"],
        scope: params["scope"],
        state: params["state"]
      )
    )
  end
end
