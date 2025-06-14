defmodule BorutaWeb.AuthorizeError do
  @enforce_keys [:message]
  defexception [:message, :plug_status]
end

defmodule BorutaWeb.Oauth.AuthorizeController do
  @dialyzer :no_match
  @behaviour Boruta.Oauth.AuthorizeApplication

  use BorutaWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [request_param: 1, get_user_session: 1]

  alias Boruta.ClientsAdapter
  alias Boruta.Oauth
  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid.CredentialOfferResponse
  alias Boruta.Openid.SiopV2Response
  alias Boruta.Openid.VerifiablePresentationResponse
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.VerifiableCredentials
  alias BorutaIdentity.Accounts.VerifiablePresentations
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.ResourceOwners
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes
  alias BorutaIdentityWeb.TemplateView

  def authorize(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns[:current_user]

    conn = put_unsigned_request(conn)

    with {:unchanged, conn} <- public_client?(conn),
         {:unchanged, conn} <- prompt_redirection(conn, current_user),
         {:unchanged, conn} <- verifiable_presentation?(conn),
         {:unchanged, conn} <- max_age_redirection(conn, current_user),
         {:unchanged, conn} <- check_preauthorized(conn),
         {:unchanged, conn} <- redirect_if_mfa_required(conn, current_user),
         {:unchanged, conn} <- preauthorize(conn, current_user) do
      redirect(conn,
        to:
          IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{
            request: request_param(conn)
          })
      )
    else
      {:preauthorized, conn} ->
        do_authorize(conn, current_user)

      {:preauthorize, conn} ->
        conn

      {:authorize, conn} ->
        conn

      {:redirected, conn} ->
        conn
    end
  end

  def public_client?(%Plug.Conn{query_params: %{"client_id" => "did:" <> _key}} = conn) do
    {:preauthorized, conn}
  end

  def public_client?(
        %Plug.Conn{
          query_params: %{"response_type" => "id_token", "client_metadata" => _client_metadata}
        } = conn
      ) do
    {:preauthorized, conn}
  end

  def public_client?(
        %Plug.Conn{
          query_params: %{"response_type" => "id_token urn:ietf:params:oauth:response-type:pre-authorized_code", "client_metadata" => _client_metadata}
        } = conn
      ) do
    {:preauthorized, conn}
  end

  def public_client?(
        %Plug.Conn{
          query_params: %{"response_type" => "id_token vp_token", "client_metadata" => _client_metadata}
        } = conn
      ) do
    {:preauthorized, conn}
  end

  def public_client?(
        %Plug.Conn{
          query_params: %{"response_type" => "code", "client_metadata" => _client_metadata}
        } = conn
      ) do
        {:preauthorized, conn}
  end

  def public_client?(conn) do
    {:unchanged, conn}
  end

  def verifiable_presentation?(conn) do
    case conn.query_params["client_metadata"] do
      "" <> _key ->
        {:preauthorized, conn}

      _ ->
        {:unchanged, conn}
    end
  end

  defp redirect_if_mfa_required(conn, current_user) do
    case ensure_mfa(conn, current_user) do
      :ok ->
        {:unchanged, conn}

      {:error, action, reason} ->
        case get_session(conn, :session_chosen) do
          true ->
            conn =
              conn
              |> put_flash(:warning, reason)
              |> redirect(
                to:
                  IdentityRoutes.user_session_path(
                    BorutaIdentityWeb.Endpoint,
                    action,
                    %{
                      request: request_param(conn)
                    }
                  )
              )

            {:redirected, conn}

          _ ->
            conn =
              conn
              |> put_flash(:warning, reason)
              |> redirect(
                to:
                  IdentityRoutes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{
                    request: request_param(conn)
                  })
              )

            {:redirected, conn}
        end
    end
  end

  defp ensure_mfa(%Plug.Conn{query_params: query_params} = conn, current_user) do
    identity_provider =
      IdentityProviders.get_identity_provider_by_client_id(query_params["client_id"])

    totp_authenticated = (get_session(conn, :totp_authenticated) || %{})[get_user_session(conn)]

    webauthn_authenticated =
      (get_session(conn, :webauthn_authenticated) || %{})[get_user_session(conn)]

    do_enforce_mfa(identity_provider, current_user, totp_authenticated, webauthn_authenticated)
  end

  defp do_enforce_mfa(
         %IdentityProvider{enforce_totp: false, enforce_webauthn: false},
         %User{totp_registered_at: nil},
         _totp_authenticated,
         _webauthn_authenticated
       ) do
    :ok
  end

  defp do_enforce_mfa(
         %IdentityProvider{webauthnable: true},
         %User{webauthn_registered_at: %DateTime{}},
         _totp_authenticated,
         webauthn_authenticated
       ) do
    case webauthn_authenticated do
      true ->
        :ok

      _ ->
        {:error, :initialize_webauthn, "Multi factor authentication required."}
    end
  end

  defp do_enforce_mfa(
         %IdentityProvider{totpable: true},
         %User{totp_registered_at: %DateTime{}},
         totp_authenticated,
         _webauthn_authenticated
       ) do
    case totp_authenticated do
      true ->
        :ok

      _ ->
        {:error, :initialize_totp, "Multi factor authentication required."}
    end
  end

  defp do_enforce_mfa(
         %IdentityProvider{enforce_webauthn: true},
         %User{webauthn_registered_at: nil},
         _totp_authenticated,
         webauthn_authenticated
       ) do
    case webauthn_authenticated do
      true ->
        :ok

      _ ->
        {:error, :initialize_webauthn, "Multi factor authentication required."}
    end
  end

  defp do_enforce_mfa(
         %IdentityProvider{enforce_totp: true},
         %User{totp_registered_at: nil},
         totp_authenticated,
         _webauthn_authenticated
       ) do
    case totp_authenticated do
      true ->
        :ok

      _ ->
        {:error, :initialize_totp, "Multi factor authentication required."}
    end
  end

  defp do_enforce_mfa(_identity_provider, _user, _totp_authenticated, _webauthn_authenticated) do
    :ok
  end

  defp check_preauthorized(conn) do
    case get_session(conn, :preauthorizations) do
      nil ->
        {:unchanged, conn}

      preauthorizations ->
        case Map.get(preauthorizations, request_param(conn), false) do
          false ->
            {:unchanged, conn}

          true ->
            preauthorizations = get_session(conn, :preauthorizations) || %{}

            {:preauthorized,
             conn
             |> put_session(
               :preauthorizations,
               Map.delete(preauthorizations, request_param(conn))
             )}
        end
    end
  end

  defp max_age_redirection(
         %Plug.Conn{query_params: %{"max_age" => max_age}} = conn,
         %User{} = current_user
       ) do
    case login_expired?(current_user, max_age) do
      true ->
        conn =
          redirect(conn,
            to:
              IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{
                request: request_param(conn)
              })
          )

        {:redirected, conn}

      false ->
        {:unchanged, conn}
    end
  end

  defp max_age_redirection(conn, _current_user), do: {:unchanged, conn}

  defp prompt_redirection(
         %Plug.Conn{query_params: %{"prompt" => "none"} = query_params} = conn,
         current_user
       ) do
    case ensure_mfa(conn, current_user) do
      :ok ->
        {:authorize, do_authorize(conn, current_user)}

      {:error, _action, reason} ->
        {:redirected,
         authorize_error(conn, %Error{
           status: :unauthorized,
           format: :fragment,
           redirect_uri: query_params["redirect_uri"],
           error: :login_required,
           error_description: reason
         })}
    end
  end

  defp prompt_redirection(%Plug.Conn{query_params: %{"prompt" => "login"}} = conn, _current_user) do
    conn =
      redirect(conn,
        to:
          IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{
            request: request_param(conn)
          })
      )

    {:redirected, conn}
  end

  defp prompt_redirection(conn, _current_user), do: {:unchanged, conn}

  defp preauthorize(conn, current_user) do
    conn =
      conn
      |> Oauth.preauthorize(
        resource_owner(conn, current_user),
        __MODULE__
      )

    {:preauthorize, conn}
  end

  defp do_authorize(conn, current_user) do
    conn
    |> delete_session(:preauthorizations)
    |> Oauth.authorize(
      resource_owner(conn, current_user),
      __MODULE__
    )
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(conn, %AuthorizationSuccess{sub: "did:" <> _key = sub}) do
    Oauth.authorize(
      conn,
      %ResourceOwner{
        sub: sub,
        presentation_configuration: VerifiablePresentations.public_presentation_configuration()
      },
      __MODULE__
    )
  end

  def preauthorize_success(conn, _authorization) do
    session_chosen? = get_session(conn, :session_chosen) || false
    preauthorizations = get_session(conn, :preauthorizations) || %{}

    case session_chosen? do
      true ->
        conn
        |> put_session(
          :preauthorizations,
          Map.merge(preauthorizations, %{request_param(conn) => true})
        )
        |> redirect(
          to:
            IdentityRoutes.user_consent_path(BorutaIdentityWeb.Endpoint, :index, %{
              request: request_param(conn)
            })
        )

      false ->
        conn
        |> redirect(
          to:
            IdentityRoutes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{
              request: request_param(conn)
            })
        )
    end
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_error(conn, error) do
    session_chosen? = get_session(conn, :session_chosen) || false

    case {session_chosen?, conn.assigns[:current_user]} do
      {true, _current_user} ->
        authorize_error(conn, error)

      {false, _current_user} ->
        case request_param(conn) do
          "" ->
            authorize_error(conn, error)

          request ->
            conn
            |> redirect(
              to:
                IdentityRoutes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{
                  request: request
                })
            )
        end
    end
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(
        %Plug.Conn{query_params: query_params} = conn,
        %AuthorizeResponse{} = response
      ) do
    # TODO get client_id, grant_type and resource_owner from response
    client_id = query_params["client_id"]
    current_user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authorization, :authorize, :success],
      %{},
      %{
        access_token: response.access_token,
        code: response.code,
        type: response.type,
        response_mode: response.response_mode,
        expires_in: response.expires_in,
        client_id: client_id,
        current_user: current_user
      }
    )

    conn
    |> delete_session(:session_chosen)
    |> redirect(external: AuthorizeResponse.redirect_to_url(response))
  end

  def authorize_success(
        %Plug.Conn{} = conn,
        %SiopV2Response{response_mode: "post"} = response
      ) do
    {:ok, idp} = Accounts.Utils.client_identity_provider(response.client.id)

    template =
      IdentityProviders.get_identity_provider_template!(idp.id, :cross_device_presentation)

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        presentation_deeplink:
          SiopV2Response.redirect_to_deeplink(response, fn code ->
            uri = URI.parse(Boruta.Config.issuer())

            %{uri | path: Routes.token_path(conn, :direct_post, code)}
            |> URI.to_string()
          end)
      }
    )
  end

  def authorize_success(
        %Plug.Conn{} = conn,
        %SiopV2Response{response_mode: "direct_post"} = response
      ) do
    # TODO log business event

    conn
    |> redirect(
      external:
        SiopV2Response.redirect_to_deeplink(response, fn code ->
          uri = URI.parse(Boruta.Config.issuer())

          %{uri | path: Routes.token_path(conn, :direct_post, code)}
          |> URI.to_string()
        end)
    )
  end

  def authorize_success(
        %Plug.Conn{} = conn,
        %VerifiablePresentationResponse{response_mode: "direct_post"} = response
      ) do
    # TODO log business event

    conn
    |> redirect(
      external:
        VerifiablePresentationResponse.redirect_to_deeplink(response, fn code ->
          uri = URI.parse(Boruta.Config.issuer())

          %{uri | path: Routes.token_path(conn, :direct_post, code)}
          |> URI.to_string()
        end)
    )
  end

  def authorize_success(
        %Plug.Conn{} = conn,
        %VerifiablePresentationResponse{response_mode: "post"} = response
      ) do
    {:ok, idp} = Accounts.Utils.client_identity_provider(response.client.id)

    template =
      IdentityProviders.get_identity_provider_template!(idp.id, :cross_device_presentation)

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        presentation_deeplink:
          VerifiablePresentationResponse.redirect_to_deeplink(response, fn code ->
            uri = URI.parse(Boruta.Config.issuer())

            %{uri | path: Routes.token_path(conn, :direct_post, code)}
            |> URI.to_string()
          end)
      }
    )
  end

  def authorize_success(
        %Plug.Conn{query_params: query_params} = conn,
        %CredentialOfferResponse{tx_code: tx_code, tx_code_required: true} = response
      ) do
    current_user = conn.assigns[:current_user]

    case IdentityProviders.get_identity_provider_by_client_id(query_params["client_id"]) do
      %IdentityProvider{} = identity_provider ->
        template =
          IdentityProviders.get_identity_provider_template!(
            identity_provider.id,
            :credential_offer
          )

        case Deliveries.deliver_tx_code(identity_provider.backend, current_user, tx_code) do
          :ok ->
            conn
            |> delete_session(:session_chosen)
            |> put_layout(false)
            |> put_view(TemplateView)
            |> render("template.html", template: template, assigns: %{credential_offer: response})

          {:error, _error} ->
            {:error, :bad_request}
        end

      nil ->
        raise BorutaIdentity.Accounts.IdentityProviderError,
              "identity provider not configured for given OAuth client. Please contact your administrator."
    end
  end

  def authorize_success(
        %Plug.Conn{query_params: query_params} = conn,
        %CredentialOfferResponse{} = response
      ) do
        client_id = case query_params["client_id"] do
          "did" <> _key ->
            ClientsAdapter.public!().id
          client_id ->
            client_id
        end
    case IdentityProviders.get_identity_provider_by_client_id(client_id) do
      %IdentityProvider{} = identity_provider ->
        template =
          IdentityProviders.get_identity_provider_template!(
            identity_provider.id,
            :credential_offer
          )

        conn
        |> delete_session(:session_chosen)
        |> put_layout(false)
        |> put_view(TemplateView)
        |> render("template.html", template: template, assigns: %{credential_offer: response})

      nil ->
        raise BorutaIdentity.Accounts.IdentityProviderError,
              "identity provider not configured for given OAuth client. Please contact your administrator."
    end
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(
        %Plug.Conn{} = conn,
        %Error{status: :unauthorized, error: :login_required} = error
      ) do
    redirect(conn, external: Error.redirect_to_url(error))
  end

  def authorize_error(
        %Plug.Conn{} = conn,
        %Error{status: :unauthorized, error: :invalid_resource_owner} = error
      ) do
    emit_authorize_error_event(conn, error)

    conn
    |> delete_session(:session_chosen)
    |> delete_session(:totp_authenticated)
    |> redirect(
      to:
        IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{
          request: request_param(conn)
        })
    )
  end

  def authorize_error(conn, %Error{format: format} = error)
      when not is_nil(format) do
    emit_authorize_error_event(conn, error)

    conn
    |> delete_session(:session_chosen)
    |> delete_session(:totp_authenticated)
    |> redirect(external: Error.redirect_to_url(error))
  end

  def authorize_error(
        conn,
        %Error{status: status, error_description: error_description} = error
      ) do
    emit_authorize_error_event(conn, error)

    conn
    |> delete_session(:session_chosen)
    |> delete_session(:totp_authenticated)
    |> put_status(status)

    raise %BorutaWeb.AuthorizeError{message: error_description, plug_status: status}
  end

  defp emit_authorize_error_event(%Plug.Conn{query_params: query_params} = conn, error) do
    # TODO get client_id and grant_type from error
    client_id = query_params["client_id"]
    current_user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authorization, :authorize, :failure],
      %{},
      %{
        status: error.status,
        error: error.error,
        error_description: error.error_description,
        client_id: client_id,
        current_user: current_user
      }
    )
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

  defp resource_owner(conn, current_user) do
    current_user = current_user || %User{}

    anonymous_sub =
      case conn.query_params["client_id"] do
        "did:" <> _key = did -> did
        _ -> nil
      end

    scope =
      case conn.query_params["scope"] do
        nil -> ""
        scope -> scope
      end

    %ResourceOwner{
      sub: current_user.id || anonymous_sub,
      username: current_user.username,
      last_login_at: current_user.last_login_at,
      extra_claims:
        Map.merge(ResourceOwners.metadata(current_user, scope), current_user.federated_metadata),
      authorization_details: VerifiableCredentials.authorization_details(current_user),
      presentation_configuration: VerifiablePresentations.presentation_configuration(current_user)
    }
  end
end
