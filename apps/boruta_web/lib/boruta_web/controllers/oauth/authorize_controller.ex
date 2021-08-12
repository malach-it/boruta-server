defmodule BorutaWeb.Oauth.AuthorizeController do
  @dialyzer :no_match
  @behaviour Boruta.Oauth.AuthorizeApplication

  use BorutaWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [log_out_user: 1]

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

    unsigned_request = with request <- Map.get(query_params, "request", ""),
         {:ok, params} <- Joken.peek_claims(request) do
      params
    else
      _ -> %{}
    end

    query_params = Map.merge(query_params, unsigned_request)

    authorize_response(
      %{conn|query_params: query_params},
      current_user,
      session_chosen,
      Accounts.consented?(current_user, conn),
      query_params["prompt"],
      query_params["max_age"]
    )
  end

  defp authorize_response(conn, %User{} = current_user, _, _, "none", _) do
    resource_owner =
      current_user && %ResourceOwner{sub: current_user.id, username: current_user.email, last_login_at: current_user.last_login_at}

    conn
    |> Oauth.authorize(
      resource_owner,
      __MODULE__
    )
  end

  defp authorize_response(conn, _, _, _, "login", _) do
    log_out_user(conn)
  end

  defp authorize_response(conn, %User{} = current_user, true, false, _, _) do
    conn
    |> Oauth.preauthorize(
      %ResourceOwner{sub: current_user.id, username: current_user.email, last_login_at: current_user.last_login_at},
      __MODULE__
    )
  end

  defp authorize_response(conn, %User{} = current_user, true, true, _, _) do
    conn
    |> Oauth.authorize(
      %ResourceOwner{sub: current_user.id, username: current_user.email, last_login_at: current_user.last_login_at},
      __MODULE__
    )
  end

  defp authorize_response(conn, %User{} = current_user, _, _, _, max_age) do
    # TODO a render can be a better choice
    now = (DateTime.utc_now() |> DateTime.to_unix())

    with "" <> max_age <- max_age,
         {max_age, _} <- Integer.parse(max_age),
         true <- now - DateTime.to_unix(current_user.last_login_at) >= max_age do
      log_out_user(conn)
    else
      _ ->
        redirect(conn, to: Routes.choose_session_path(conn, :new))
    end
  end

  defp authorize_response(conn, _, _, _, _, _) do
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
    |> delete_session(:session_chosen)
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
        |> delete_session(:session_chosen)
        |> redirect(to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
    end
  end

  def authorize_error(conn, %Error{format: format} = error)
      when not is_nil(format) do
    conn
    |> delete_session(:session_chosen)
    |> redirect(external: Error.redirect_to_url(error))
  end

  def authorize_error(
        conn,
        %Error{status: status, error: error, error_description: error_description}
      ) do
    conn
    |> delete_session(:session_chosen)
    |> put_status(status)
    |> put_view(BorutaWeb.OauthView)
    |> render("error." <> get_format(conn), error: error, error_description: error_description)
  end

  defp store_user_return_to(conn, params) do
    conn
    |> put_session(
      :user_return_to,
      current_path(conn)
      |> String.replace(~r/prompt=(login|none)/, "")
    )
  end
end
