defmodule BorutaIdentity.TotpError do
  @moduledoc false

  @enforce_keys [:message, :totp_secret]
  defexception [:message, :totp_secret, :changeset, :template, plug_status: 400]

  @type t :: %__MODULE__{
          message: String.t(),
          totp_secret: String.t(),
          changeset: Ecto.Changeset.t() | nil,
          template: BorutaIdentity.IdentityProviders.Template.t()
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, totp_secret: ""}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaIdentity.TotpRegistrationApplication do
  @moduledoc false

  @callback totp_registration_initialized(
              context :: any(),
              totp_secret :: String.t(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback totp_registration_error(
              context :: any(),
              error :: BorutaIdentity.TotpError.t()
            ) :: any()

  @callback totp_registration_success(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()
end

defmodule BorutaIdentity.TotpAuthenticationApplication do
  @moduledoc false

  @callback totp_initialized(
              context :: any(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback totp_not_required(context :: any()) :: any()

  @callback totp_registration_missing(context :: any()) :: any()

  @callback totp_authenticated(
              context :: any(),
              current_user :: BorutaIdentity.Accounts.User.t()
            ) ::
              any()

  @callback totp_authentication_failure(
              context :: any(),
              error :: BorutaIdentity.TotpError.t()
            ) :: any()
end

defmodule BorutaIdentity.Totp do
  @moduledoc false

  defmodule Hotp do
    @moduledoc """
    Implements HOTP generation as described in the IETF RFC
    [HOTP: An HMAC-Based One-Time Password Algorithm](https://www.ietf.org/rfc/rfc4226.txt)
    > This implementation defaults to 6 digits using the sha1 algorithm as hashing function
    """

    import Bitwise

    @hmac_algorithm :sha
    @digits 6

    @spec generate_hotp(secret :: String.t(), counter :: integer()) :: hotp :: String.t()
    def generate_hotp(secret, counter) do
      # Step 1: Generate an HMAC-SHA-1 value
      hmac_result = :crypto.mac(:hmac, @hmac_algorithm, secret, <<counter::size(64)>>)

      # Step 2: Dynamic truncation
      truncated_hash = truncate_hash(hmac_result)

      # Step 3: Compute HOTP value (6-digit OTP)
      hotp = truncated_hash |> rem(10 ** @digits)

      format_hotp(hotp)
    end

    defp truncate_hash(hmac_value) do
      # NOTE the folowing hard coded values are part of the specification
      offset = :binary.at(hmac_value, 19) &&& 0xF

      with <<_::size(1), result::size(31)>> <- :binary.part(hmac_value, offset, 4) do
        result
      end
    end

    defp format_hotp(hotp) do
      String.pad_leading(Integer.to_string(hotp), @digits, "0")
    end
  end

  defmodule Admin do
    @moduledoc false

    import Boruta.Config,
      only: [
        issuer: 0
      ]

    @interval 30

    @spec generate_totp(secret :: String.t()) :: totp :: String.t() | :error
    def generate_totp(secret) do
      with {:ok, secret} <- Base.decode32(secret, padding: false) do
        Hotp.generate_hotp(secret, number_of_time_steps())
      end
    end

    @spec check_totp(totp :: String.t(), secret :: String.t()) :: totp :: :ok | {:error, reason :: String.t()}
    def check_totp(totp, secret) when is_binary(secret) do
      with {:ok, secret} <- Base.decode32(secret, padding: false),
           true <- Hotp.generate_hotp(secret, number_of_time_steps()) == totp do
        :ok
      else
        _ -> {:error, "Given TOTP is invalid."}
      end
    end

    def check_totp(_totp, _secret), do: {:error, "Given TOTP is invalid."}

    def generate_secret do
      SecureRandom.uuid() |> Base.encode32(padding: false)
    end

    def url(username, secret) do
      "otpauth://totp/#{username}?secret=#{secret}&issuer=#{issuer()}"
    end

    defp number_of_time_steps do
      floor(:os.system_time(:seconds) / @interval)
    end
  end

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.Repo
  alias BorutaIdentity.TotpError

  defwithclientidp initialize_totp_registration(context, client_id, totp_authenticated, current_user, module) do
    totp_secret = Admin.generate_secret()

    case {totp_authenticated, current_user.totp_registered_at} do
      {true, _} ->
        module.totp_registration_initialized(
          context,
          totp_secret,
          new_totp_registration_template(client_idp)
        )
      {false, nil} ->
        module.totp_registration_initialized(
          context,
          totp_secret,
          new_totp_registration_template(client_idp)
        )
      _ ->
        raise TotpError, "Authenticator registration could not be initialized."
    end
  end

  defwithclientidp register_totp(context, client_id, current_user, totp_params, module) do
    with :ok <- Admin.check_totp(totp_params[:totp_code], totp_params[:totp_secret]),
         {:ok, user} <-
           current_user
           |> User.totp_changeset(totp_params[:totp_secret])
           |> Repo.update() do
      module.totp_registration_success(context, user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error = %TotpError{
          message: "Current user could not be updated.",
          changeset: changeset,
          totp_secret: totp_params[:totp_secret],
          template: new_totp_registration_template(client_idp)
        }

        module.totp_registration_error(context, error)

      {:error, error} ->
        error = %TotpError{
          message: error,
          totp_secret: totp_params[:totp_secret],
          template: new_totp_registration_template(client_idp)
        }

        module.totp_registration_error(context, error)
    end
  end

  defwithclientidp initialize_totp(context, client_id, current_user, module) do
    case {client_idp, current_user} do
      {%IdentityProvider{totpable: true}, %User{totp_registered_at: %DateTime{}}} ->
        module.totp_initialized(context, new_totp_authentication_template(client_idp))

      {%IdentityProvider{enforce_totp: true}, %User{totp_registered_at: nil}} ->
        module.totp_registration_missing(context)

      {%IdentityProvider{enforce_totp: true}, _} ->
        module.totp_initialized(context, new_totp_authentication_template(client_idp))

      {%IdentityProvider{enforce_totp: false}, _} ->
        module.totp_not_required(context)
    end
  end

  defwithclientidp authenticate_totp(context, client_id, %User{totp_registered_at: nil}, _totp_params, module) do
    case client_idp.enforce_totp do
      true ->
        module.totp_registration_missing(context)
      false ->
        module.totp_not_required(context)
    end
  end

  defwithclientidp authenticate_totp(context, client_id, user, totp_params, module) do
    case Admin.check_totp(totp_params[:totp_code], user.totp_secret) do
      :ok ->
        module.totp_authenticated(context, user)

      {:error, error} ->
        error = %TotpError{
          message: error,
          totp_secret: totp_params[:totp_secret],
          template: new_totp_authentication_template(client_idp)
        }

        module.totp_authentication_failure(context, error)
    end
  end

  defp new_totp_registration_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_totp_registration
    )
  end

  defp new_totp_authentication_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_totp_authentication
    )
  end
end
