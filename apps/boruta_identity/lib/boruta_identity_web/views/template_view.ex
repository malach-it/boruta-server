defmodule BorutaIdentityWeb.TemplateView do
  use BorutaIdentityWeb, :view

  import Boruta.Config, only: [issuer: 0]

  alias Boruta.ClientsAdapter
  alias Boruta.Oauth.Client
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentityWeb.ErrorHelpers

  def render("template.html", %{
        conn: conn,
        template: %Template{
          layout: layout,
          content: content,
          identity_provider: identity_provider
        },
        assigns: assigns
      }) do
    assigns =
      assigns
      |> Map.put(:identity_provider, identity_provider)
      |> Map.put(:conn, conn)

    context =
      context(%{}, assigns)
      |> Map.put(:messages, messages(conn))
      |> Map.put(:_csrf_token, Plug.CSRFProtection.get_csrf_token())
      |> Map.merge(errors(assigns))
      |> Map.merge(paths(conn, assigns))
      |> Map.merge(identity_provider_configurations(identity_provider))

    {:safe, Mustachex.render(layout.content, context, partials: %{inner_content: content})}
  end

  def context(context, %{conn: conn, identity_provider: identity_provider} = assigns) do
    %Plug.Conn{query_params: query_params} = conn
    request = Map.get(query_params, "request")
    backend = identity_provider.backend

    federated_servers =
      Enum.map(backend.federated_servers, fn federated_server ->
        federated_server_name = federated_server["name"]

        {federated_server_name,
         %{
           login_url:
             Routes.backends_path(
               BorutaIdentityWeb.Endpoint,
               :authorize,
               backend.id,
               federated_server_name,
               %{request: request}
             )
         }}
      end)
      |> Enum.into(%{})

    %{federated_servers: federated_servers}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :identity_provider))
  end

  def context(context, %{current_user: current_user, totp_secret: totp_secret} = assigns) do
    {:ok, base64_totp_registration_qr_code} =
      BorutaIdentity.Totp.Admin.url(current_user.username, totp_secret)
      |> QRCode.create()
      |> QRCode.render(:svg)
      |> QRCode.to_base64()

    %{
      totp_secret: totp_secret,
      base64_totp_registration_qr_code: base64_totp_registration_qr_code
    }
    |> Map.merge(context)
    |> context(Map.delete(assigns, :totp_secret))
  end

  def context(context, %{client: client} = assigns) do
    client = Map.from_struct(client)

    %{client: client}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :client))
  end

  def context(context, %{credential_offer: credential_offer} = assigns) do
    {:ok, base64_credential_offer_qr_code} =
      text_from_credential_offer(credential_offer)
      |> QRCode.create()
      |> QRCode.render(:svg)
      |> QRCode.to_base64()

    %{
      base64_credential_offer_qr_code: base64_credential_offer_qr_code,
      credential_offer_deeplink: text_from_credential_offer(credential_offer)
    }
    |> Map.merge(context)
    |> context(Map.delete(assigns, :credential_offer))
  end

  def context(context, %{current_user: current_user} = assigns) do
    current_user = Map.take(current_user, [:username, :totp_registered_at, :metadata])

    current_user = %{
      current_user
      | totp_registered_at:
          current_user.totp_registered_at &&
            current_user.totp_registered_at |> DateTime.truncate(:second) |> DateTime.to_string()
    }

    %{current_user: current_user}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :current_user))
  end

  def context(context, %{scopes: scopes} = assigns) do
    scopes = Enum.map(scopes, &Map.from_struct/1)

    %{scopes: scopes}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :scopes))
  end

  def context(context, %{}) do
    client = ClientsAdapter.public!()

    {:ok, base64_siopv2_qr_code} =
      siopv2_request_from_client(client)
      |> QRCode.create()
      |> QRCode.render(:svg)
      |> QRCode.to_base64()

    %{base64_siopv2_qr_code: base64_siopv2_qr_code}
    |> Map.merge(context)
  end

  defp siopv2_request_from_client(client) do
    siopv2_request = %{
      client_id: issuer(),
      redirect_uri: issuer(),
      response_type: "vp_token",
      scope: "openid",
      nonce: "nonce",
      authorization_details: %{
        type: "openid_credential",
        format: "jwt_vc_json"
      },
      client_metadata: %{
        "authorization_endpoint" => issuer() <> "/oauth/authorize",
        "token_endpoint" => issuer() <> "/oauth/token",
        "jwks_uri" => issuer() <> "/openid/jwks",
        "credential_uri" => issuer() <> "/openid/credential"
      }
    }

    query =
      %{
        request: Client.Crypto.id_token_sign(siopv2_request, client),
        response_mode: "post",
        client_id: "did:key:test",
        presentation_definition: %{
          input_descriptors: [
            %{
              id: "linkedin email",
              format: %{
                jwt_vc_json: %{
                  proof_type: ["Ed25519Signature2018"]
                }
              },
              constraints: %{
                fields: [
                  %{path: ["$.linkedin_email"]}
                ]
              }
            }
          ]
        } |> Jason.encode!()
      }
      |> URI.encode_query()

    %URI{
      scheme: "siopv2",
      host: "",
      query: query
    } |> URI.to_string()
  end

  defp text_from_credential_offer(credential_offer) do
    # TODO Jason.Encode implementation for CredentialOfferResponse
    "openid-credential-offer://?credential_offer=#{credential_offer |> Map.from_struct() |> Jason.encode!() |> URI.encode_www_form()}"
  end

  defp paths(conn, assigns) do
    %Plug.Conn{query_params: query_params} = conn
    request = Map.get(query_params, "request")

    %{
      boruta_logo_path: Routes.static_path(BorutaIdentityWeb.Endpoint, "/images/logo-yellow.png"),
      choose_session_path:
        Routes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{request: request}),
      create_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_confirmation_path:
        Routes.user_confirmation_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_consent_path: Routes.user_consent_path(conn, :consent, %{request: request}),
      create_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_session_totp_authentication_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :authenticate_totp, %{
          request: request
        }),
      delete_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request}),
      edit_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :edit, %{request: request}),
      new_user_totp_registration_path:
        Routes.totp_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      create_user_totp_registration_path:
        Routes.totp_path(BorutaIdentityWeb.Endpoint, :register, %{request: request}),
      new_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      update_user_reset_password_path:
        Routes.user_reset_password_path(
          BorutaIdentityWeb.Endpoint,
          :update,
          Map.get(assigns, :token, ""),
          %{request: request}
        ),
      update_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :update, %{request: request})
    }
  end

  defp errors(%{errors: errors}) do
    formatted_errors = Enum.map(errors, &%{message: &1})

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(%{changeset: changeset}) do
    formatted_errors =
      changeset
      |> ErrorHelpers.error_messages()
      |> Enum.map(fn message -> %{message: message} end)

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(_assigns), do: %{errors: [], valid?: true}

  defp messages(conn) do
    get_flash(conn)
    |> Enum.map(fn {type, value} ->
      %{
        "type" => type,
        "content" => value
      }
    end)
  end

  defp identity_provider_configurations(identity_provider) do
    %{
      registrable?: identity_provider.registrable,
      totpable?: identity_provider.totpable,
      user_editable?: identity_provider.user_editable
    }
  end
end
