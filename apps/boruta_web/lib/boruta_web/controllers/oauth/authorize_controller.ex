defmodule BorutaWeb.Oauth.AuthorizeController do
  @dialyzer :no_match
  @behaviour Boruta.Oauth.AuthorizeApplication
  @behaviour BorutaIdentity.Accounts.ConsentApplication

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes
  alias BorutaWeb.OauthView

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
    case {get_session(conn, :session_chosen), Accounts.consented?(current_user, conn)} do
      {true, false} ->
        conn
        |> Oauth.preauthorize(
          %ResourceOwner{
            sub: current_user.id,
            username: current_user.email,
            last_login_at: current_user.last_login_at
          },
          __MODULE__
        )

      {true, true} ->
        conn
        |> Oauth.authorize(
          %ResourceOwner{
            sub: current_user.id,
            username: current_user.email,
            last_login_at: current_user.last_login_at
          },
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
  def preauthorize_success(conn, %AuthorizationSuccess{client: client} = authorization) do
    # TODO redirect to identity consent controller
    Accounts.initialize_consent(conn, client.id, authorization, __MODULE__)
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

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_initialized(conn, client, scopes, template) do
    conn
    |> put_view(OauthView)
    |> put_layout(false)
    |> render("preauthorize.html", template: compile_template(template, %{
      conn: conn,
      request: request_param(conn),
      scopes: scopes,
      client: client
    }))
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
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

  defp request_param(conn) do
    case Oauth.Request.authorize_request(conn, %ResourceOwner{sub: ""}) do
      {:ok, %_{client_id: client_id}} ->
        {:ok, jwt, _payload} =
          Joken.encode_and_sign(
            %{
              "client_id" => client_id,
              # TODO keep prompt and max_age params
              "user_return_to" => user_return_to(conn)
            },
            BorutaIdentityWeb.Token.application_signer()
          )

        jwt

      _ ->
        ""
    end
  end

  def user_return_to(conn) do
    current_path(conn)
    |> String.replace(~r/prompt=(login|none)/, "")
    |> String.replace(~r/max_age=(\d+)/, "")
  end

  defp compile_template(%Template{layout: layout, content: content}, opts) do
    conn = Map.fetch!(opts, :conn)
    request = Map.fetch!(opts, :request)
    scopes = Map.fetch!(opts, :scopes) |> Enum.map(&Map.from_struct/1)
    client = Map.fetch!(opts, :client) |> Map.from_struct()

    messages =
      get_flash(conn)
      |> Enum.map(fn {type, value} ->
        %{
          "type" => type,
          "content" => value
        }
      end)

    context = %{
      create_user_consent_path: IdentityRoutes.consent_path(BorutaIdentityWeb.Endpoint, :consent, %{request: request}),
      client: client,
      scopes: scopes,
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      messages: messages,
    }

    Mustachex.render(layout.content, context, partials: %{inner_content: content})
  end
end
