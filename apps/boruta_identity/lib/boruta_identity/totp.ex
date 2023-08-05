defmodule BorutaIdentity.TotpError do
  @enforce_keys [:message, :totp_secret]
  defexception [:message, :totp_secret, :changeset, :template]

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

defmodule BorutaIdentity.TotpApplication do
  @callback totp_registration_initialized(
              context :: any(),
              totp_secret :: String.t(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback totp_registration_error(
              context :: any(),
              BorutaIdentity.TotpError.t()
            ) :: any()

  @callback totp_registration_success(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()
end

defmodule BorutaIdentity.Totp do
  @moduledoc false

  defmodule Hotp do
    @moduledoc false

    import Bitwise

    @hmac_algorithm :sha
    @digits 6

    def generate_hotp(secret, counter) do
      # Step 1: Generate an HMAC-SHA-1 value
      hmac_result = :crypto.mac(:hmac, @hmac_algorithm, secret, <<counter::size(64)>>)

      # Step 2: Dynamic truncation
      truncated_hash = truncate_hash(hmac_result)

      # Step 3: Compute HOTP value (6-digit OTP)
      hotp = truncated_hash |> rem(1_000_000)

      format_hotp(hotp)
    end

    def truncate_hash(hmac_value) do
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

    def generate_totp(secret) do
      secret = Base.decode32!(secret)

      Hotp.generate_hotp(secret, number_of_time_steps())
    end

    def check_totp(totp, secret) when is_binary(secret) do
      dbg secret
      secret = Base.decode32!(secret, padding: false)

      case Hotp.generate_hotp(secret, number_of_time_steps()) |> dbg == totp do
        true -> :ok
        false -> {:error, "Given TOTP is invalid."}
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
      floor(:os.system_time(:seconds) / 30)
    end
  end

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.TotpError
  alias BorutaIdentity.Repo

  defwithclientidp initialize_totp_registration(context, client_id, module) do
    totp_secret = Admin.generate_secret()

    module.totp_registration_initialized(
      context,
      totp_secret,
      new_totp_registration_template(client_idp)
    )
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

  defp new_totp_registration_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_totp_registration
    )
  end
end
