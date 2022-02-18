defmodule BorutaWeb.Oauth.AuthorizeController do
  @dialyzer :no_match
  @behaviour Boruta.Oauth.AuthorizeApplication

  use BorutaWeb, :controller
  import BorutaIdentityWeb.Authenticable, only: [request_param: 1, user_return_to: 1]

  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes

  def authorize(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns[:current_user]

    conn = put_unsigned_request(conn)

    with {:unchanged, conn} <- prompt_redirection(conn, current_user),
         {:unchanged, conn} <- max_age_redirection(conn, current_user),
         {:unchanged, conn} <- do_authorize(conn, current_user) do
      redirect(conn,
        to:
          IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{
            request: request_param(conn)
          })
      )
    end
  end

  def prompt_redirection(%Plug.Conn{query_params: %{"prompt" => "none"}} = conn, current_user) do
    current_user = current_user || %User{}

    resource_owner = %ResourceOwner{
      sub: current_user.id,
      username: current_user.email,
      last_login_at: current_user.last_login_at
    }

    conn
    |> Oauth.authorize(
      resource_owner,
      __MODULE__
    )
  end

  def prompt_redirection(%Plug.Conn{query_params: %{"prompt" => "login"}} = conn, _current_user) do
    redirect(conn,
      to:
        IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{
          request: request_param(conn)
        })
    )
  end

  def prompt_redirection(conn, _current_user), do: {:unchanged, conn}

  def prompt_redirection(conn), do: {:unchanged, conn}

  def max_age_redirection(
        %Plug.Conn{query_params: %{"max_age" => max_age}} = conn,
        %User{} = current_user
      ) do
    case login_expired?(current_user, max_age) do
      true ->
        redirect(conn,
          to:
            IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{
              request: request_param(conn)
            })
        )

      false ->
        {:unchanged, conn}
    end
  end

  def max_age_redirection(conn, _current_user), do: {:unchanged, conn}

  def do_authorize(conn, %User{} = current_user) do
    resource_owner = %ResourceOwner{
      sub: current_user.id,
      username: current_user.email,
      last_login_at: current_user.last_login_at
    }

    preauthorized? =
      case get_session(conn, :preauthorizations) do
        nil ->
          false

        preauthorizations ->
          Map.get(preauthorizations, request_param(conn)) || false
      end
    session_chosen? = get_session(conn, :session_chosen)

    case {session_chosen?, preauthorized?} do
      {true, true} ->
        conn
        |> delete_session(:preauthorizations)
        |> Oauth.authorize(
          resource_owner,
          __MODULE__
        )

      {true, false} ->
        conn
        |> put_session(:preauthorized, %{request_param(conn) => true})
        |> Oauth.preauthorize(
          resource_owner,
          __MODULE__
        )

      _ ->
        conn
        |> put_session(:session_chosen, true)
        |> put_view(BorutaWeb.ChooseSessionView)
        |> render("new.html",
          request_param: request_param(conn),
          authorize_url: user_return_to(conn)
        )
    end
  end

  def do_authorize(conn, _current_user), do: {:unchanged, conn}

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(conn, _authorization) do
    # TODO redirect to identity consent controller
    redirect(conn,
      to:
        IdentityRoutes.consent_path(BorutaIdentityWeb.Endpoint, :index, %{
          request: request_param(conn)
        })
    )
  end

  @impl Boruta.Oauth.AuthorizeApplication
  defdelegate preauthorize_error(conn, error), to: __MODULE__, as: :authorize_error

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(conn, response) do
    conn
    |> delete_session(:session_chosen)
    |> redirect(external: AuthorizeResponse.redirect_to_url(response))
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(
        %Plug.Conn{query_params: query_params} = conn,
        %Error{status: :unauthorized, error: :invalid_resource_owner} = error
      ) do
    case query_params["prompt"] do
      "none" ->
        # TODO move this to boruta_auth
        authorize_error(conn, %{
          error
          | error: :login_required,
            format: :fragment,
            redirect_uri: query_params["redirect_uri"]
        })

      _ ->
        conn
        |> delete_session(:session_chosen)
        |> redirect(
          to:
            IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{
              request: request_param(conn)
            })
        )
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

  defp login_expired?(current_user, max_age) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with "" <> max_age <- max_age,
         {max_age, _} <- Integer.parse(max_age),
         true <- now - DateTime.to_unix(current_user.last_login_at) >= max_age do
      true
    else
      _ -> false
    end
  end

  defp put_unsigned_request(%Plug.Conn{query_params: query_params} = conn) do
    unsigned_request =
      with request <- Map.get(query_params, "request", ""),
           {:ok, params} <- Joken.peek_claims(request) do
        params
      else
        _ -> %{}
      end

    query_params = Map.merge(query_params, unsigned_request)

    %{conn | query_params: query_params}
  end
end
