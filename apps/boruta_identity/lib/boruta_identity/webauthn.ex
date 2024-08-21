defmodule BorutaIdentity.WebauthnError do
  @moduledoc false

  @enforce_keys [:message]
  defexception [:message, :webauthn_options, :template, plug_status: 500]

  @type t :: %__MODULE__{
          message: String.t(),
          webauthn_options: BorutaIdentity.Webauthn.Options.t() | nil,
          template: BorutaIdentity.IdentityProviders.Template.t()
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaIdentity.WebauthnRegistrationApplication do
  @moduledoc false

  @callback webauthn_registration_initialized(
              context :: any(),
              webauthn_options :: BorutaIdentity.Webauthn.Options.t(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback webauthn_registration_error(
              context :: any(),
              error :: BorutaIdentity.TotpError.t()
            ) :: any()

  @callback webauthn_registration_success(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()
end

defmodule BorutaIdentity.WebauthnAuthenticationApplication do
  @moduledoc false

  @callback webauthn_initialized(
              context :: any(),
              webauthn_options :: BorutaIdentity.Webauthn.Options.t(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback webauthn_not_required(context :: any()) :: any()

  @callback webauthn_registration_missing(context :: any()) :: any()

  @callback webauthn_authenticated(
              context :: any(),
              current_user :: BorutaIdentity.Accounts.User.t()
            ) ::
              any()

  @callback webauthn_authentication_failure(
              context :: any(),
              error :: BorutaIdentity.TotpError.t()
            ) :: any()
end

defmodule BorutaIdentity.Webauthn do
  @moduledoc false

  defmodule Options do
    @moduledoc false

    alias Boruta.Config

    @type t :: %__MODULE__{
            rp: %{
              id: String.t()
            },
            user: %{
              id: String.t(),
              displayName: String.t()
            },
            challenge: String.t(),
            credential_id: String.t(),
            publicKeyCredParams: %{
              alg: integer(),
              type: String.t()
            }
          }

    @cose_alg_identifier %{
      "ES256" => -7,
      "ES384" => -35,
      "ES512" => -36,
      "EdDSA" => -8
    }

    @enforce_keys [:user, :challenge]
    defstruct rp: %{
                id: Config.issuer() |> URI.parse() |> Map.get(:host),
                name: "boruta"
              },
              user: nil,
              challenge: nil,
              credential_id: nil,
              publicKeyCredParams: %{
                alg: @cose_alg_identifier["ES256"],
                type: "public-key"
              }
  end

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias Boruta.Config
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.Repo
  alias BorutaIdentity.WebauthnError

  @spec options(user :: User.t(), create_challenge :: boolean()) ::
          {:ok, options :: Options.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def options(user, true) do
    with {:ok, user} <- Accounts.put_user_webauthn_challenge(user) do
      options = %Options{
        user: %{
          id: user.id,
          name: user.username,
          displayName: user.username
        },
        challenge: user.webauthn_challenge,
        credential_id: user.webauthn_identifier
      }

      {:ok, options}
    end
  end

  def options(user, false) do
    options = %Options{
      user: %{
        id: user.id,
        name: user.username,
        displayName: user.username
      },
      challenge: user.webauthn_challenge
    }

    {:ok, options}
  end

  defwithclientidp initialize_webauthn_registration(context, client_id, current_user, module) do
    case options(current_user, true) do
      {:ok, webauthn_options} ->
        module.webauthn_registration_initialized(
          context,
          webauthn_options,
          new_webauthn_registration_template(client_idp)
        )

      {:error, %Ecto.Changeset{}} ->
        raise WebauthnError, "Authenticator registration could not be initialized."
    end
  end

  defwithclientidp initialize_webauthn(context, client_id, current_user, module) do
    {:ok, webauthn_options} = options(current_user, true)

    case {client_idp, current_user} do
      {%IdentityProvider{webauthnable: true}, %User{webauthn_registered_at: %DateTime{}}} ->
        module.webauthn_initialized(
          context,
          webauthn_options,
          new_webauthn_authentication_template(client_idp)
        )

      {%IdentityProvider{enforce_webauthn: true}, %User{webauthn_registered_at: nil}} ->
        module.webauthn_registration_missing(context)

      {%IdentityProvider{enforce_webauthn: true}, _} ->
        module.webauthn_initialized(
          context,
          webauthn_options,
          new_webauthn_authentication_template(client_idp)
        )

      {%IdentityProvider{enforce_webauthn: false}, _} ->
        module.webauthn_not_required(context)
    end
  end

  defwithclientidp register_webauthn(context, client_id, current_user, webauthn_params, module) do
    %{
      attestation: attestation,
      client_data: client_data,
      identifier: identifier,
      type: "public-key"
    } = webauthn_params

    wax_challenge =
      Wax.new_registration_challenge(
        origin: Config.issuer(),
        attestation: "direct",
        rp_id: "localhost",
        trusted_attestation_types: [:basic, :uncertain, :attca, :anonca],
        verify_trust_root: false
      )

    wax_challenge = %{wax_challenge | bytes: current_user.webauthn_challenge}

    with {:ok, attestation} <- Base.decode64(attestation),
         {:ok, {authenticator_data, _result}} <-
           Wax.register(attestation, client_data, wax_challenge),
         {:ok, user} <-
           current_user
           |> User.webauthn_public_key_changeset(
             authenticator_data.attested_credential_data.credential_public_key,
             identifier
           )
           |> Repo.update() do
      module.webauthn_registration_success(context, user)
    else
      _ ->
        # TODO provide more meaningful errors
        case options(current_user, true) do
          {:ok, webauthn_options} ->
            error = %WebauthnError{
              message: "Authenticator could not be registered.",
              webauthn_options: webauthn_options,
              template: new_webauthn_registration_template(client_idp)
            }

            module.webauthn_registration_error(context, error)

          {:error, %Ecto.Changeset{}} ->
            raise WebauthnError, "Authenticator registration could not be initialized."
        end
    end
  end

  defwithclientidp authenticate_webauthn(
                     context,
                     client_id,
                     current_user,
                     webauthn_params,
                     module
                   ) do
    %{
      signature: signature,
      authenticator_data: authenticator_data,
      client_data: client_data,
      identifier: identifier,
    } = webauthn_params

    wax_challenge = Wax.new_registration_challenge([
      origin: "http://localhost:4000",
      attestation: "direct",
      rp_id: "localhost",
      trusted_attestation_types: [:basic, :uncertain, :attca, :anonca],
      verify_trust_root: false,
      allow_credentials: [{current_user.webauthn_identifier, current_user.webauthn_public_key}]
    ])
    wax_challenge = %{wax_challenge|bytes: current_user.webauthn_challenge}

    case Wax.authenticate(
       identifier,
       Base.decode64!(authenticator_data),
       Base.decode64!(signature),
       client_data,
      wax_challenge,
      []
    ) do
      {:ok, _auth_data} ->
        module.webauthn_authenticated(context, current_user)
      {:error, _error} ->
        case options(current_user, true) do
          {:ok, webauthn_options} ->
            error = %WebauthnError{
              message: "Passkey could not be verified.",
              webauthn_options: webauthn_options,
              template: new_webauthn_authentication_template(client_idp)
            }

            module.webauthn_authentication_failure(context, error)

          {:error, %Ecto.Changeset{}} ->
            raise WebauthnError, "Authenticator registration could not be initialized."
        end
    end

  end

  defp new_webauthn_registration_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_webauthn_registration
    )
  end

  defp new_webauthn_authentication_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_webauthn_authentication
    )
  end
end
