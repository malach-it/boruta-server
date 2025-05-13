defmodule BorutaIdentityWeb.TemplateView do
  use BorutaIdentityWeb, :view

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

  def context(context, %{presentation_deeplink: presentation_deeplink} = assigns) do
    {:ok, base64_presentation_qr_code} = presentation_deeplink
      |> QRCode.create()
      |> QRCode.render(:svg)
      |> QRCode.to_base64()

    %{
      base64_presentation_qr_code: base64_presentation_qr_code,
      presentation_deeplink: presentation_deeplink
    }
    |> Map.merge(context)
    |> context(Map.delete(assigns, :presentation_deeplink))
  end

  def context(context, %{webauthn_options: webauthn_options} = assigns) do
    options = Map.from_struct(webauthn_options)

    %{webauthn_options: options}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :webauthn_options))
  end

  def context(context, %{current_user: current_user} = assigns) do
    current_user = Map.take(current_user, [:username, :webauthn_registered_at, :totp_registered_at, :metadata])

    current_user = %{
      current_user
      | totp_registered_at:
          current_user.totp_registered_at &&
            current_user.totp_registered_at |> DateTime.truncate(:second) |> DateTime.to_string(),
      webauthn_registered_at:
          current_user.webauthn_registered_at &&
            current_user.webauthn_registered_at |> DateTime.truncate(:second) |> DateTime.to_string()
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

  def context(context, %{code: code} = assigns) do

    %{code: code}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :code))
  end

  def context(context, %{}), do: context

  defp text_from_credential_offer(credential_offer) do
    # TODO Jason.Encode implementation for CredentialOfferResponse
    "#{credential_offer.redirect_uri}?credential_offer=#{credential_offer
      |> Map.from_struct()
      |> Map.take([:credential_configuration_ids, :credential_issuer, :grants])
      |> Jason.encode!()
      |> URI.encode_www_form()}"
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
      create_user_session_webauthn_authentication_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :authenticate_webauthn, %{
          request: request
        }),
      delete_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request}),
      edit_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :edit, %{request: request}),
      destroy_user_path:
        Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :destroy, %{request: request}),
      new_user_totp_registration_path:
        Routes.totp_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      create_user_totp_registration_path:
        Routes.totp_path(BorutaIdentityWeb.Endpoint, :register, %{request: request}),
      new_user_webauthn_registration_path:
        Routes.webauthn_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      create_user_webauthn_registration_path:
        Routes.webauthn_path(BorutaIdentityWeb.Endpoint, :register, %{request: request}),
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
