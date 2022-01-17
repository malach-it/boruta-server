defmodule BorutaIdentity.Accounts.ResetPasswordError do
  @enforce_keys [:message]
  defexception [:message, :changeset, :token]

  @type t :: %__MODULE__{
          message: String.t(),
          token: String.t() | nil,
          changeset: Ecto.Changeset.t() | nil
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaIdentity.Accounts.ResetPasswordApplication do
  @moduledoc """
  TODO SessionApplication documentation
  """

  @callback reset_password_instructions_delivered(context :: any()) ::
              any()

  @callback password_reset_initialized(
              context :: any(),
              token :: String.t(),
              changeset :: Ecto.Changeset.t()
            ) ::
              any()

  @callback password_reseted(context :: any(), user :: BorutaIdentity.Accounts.User.t()) ::
              any()

  @callback password_reset_failure(context :: any(), error :: BorutaIdentity.Accounts.ResetPasswordError.t()) ::
              any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.ResetPasswords do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts.ResetPasswordError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties.RelyingParty

  @type reset_password_url_fun :: (token :: String.t() -> reset_password_url :: String.t())

  @type reset_password_instructions_params :: %{
          email: String.t()
        }

  @type reset_password_params :: %{
          reset_password_token: String.t(),
          password: String.t(),
          password_confirmation: String.t()
        }

  @callback send_reset_password_instructions(
              user :: User.t(),
              reset_password_url_fun :: reset_password_url_fun()
            ) ::
              :ok | {:error, reason :: String.t()}

  @callback reset_password_changeset(token :: String.t()) :: changeset :: Ecto.Changeset.t()

  @callback reset_password(reset_password_params :: reset_password_params()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t() | Ecto.Changeset.t()}

  @spec send_reset_password_instructions(
          context :: any(),
          client_id :: String.t(),
          reset_password_instructions_params :: reset_password_instructions_params(),
          reset_password_url_fun :: reset_password_url_fun(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp send_reset_password_instructions(
                      context,
                      client_id,
                      reset_password_instructions_params,
                      reset_password_url_fun,
                      module
                    ) do
    client_impl = RelyingParty.implementation(client_rp)

    with {:ok, user} <- apply(client_impl, :get_user, [reset_password_instructions_params]) do
      apply(client_impl, :send_reset_password_instructions, [user, reset_password_url_fun])
    end

    # NOTE return a success either reset passowrd instructions email sent or not
    module.reset_password_instructions_delivered(context)
  end

  @spec initialize_password_reset(
          context :: any(),
          client_id :: String.t(),
          token :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_password_reset(
                      context,
                      client_id,
                      token,
                      module
                    ) do
    client_impl = RelyingParty.implementation(client_rp)

    case apply(client_impl, :reset_password_changeset, [token]) do
      {:ok, changeset} ->
        module.password_reset_initialized(context, token, changeset)

      {:error, reason} ->
        module.password_reset_failure(context, %ResetPasswordError{message: reason, token: token})
    end
  end

  @spec reset_password(
          context :: any(),
          client_id :: String.t(),
          reset_password_params :: reset_password_params(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp reset_password(
                      context,
                      client_id,
                      reset_password_params,
                      module
                    ) do
    client_impl = RelyingParty.implementation(client_rp)

    case apply(client_impl, :reset_password, [reset_password_params]) do
      {:ok, user} ->
        module.password_reseted(context, user)

      {:error, %Ecto.Changeset{} = changeset} ->
        module.password_reset_failure(context, %ResetPasswordError{
          token: reset_password_params.reset_password_token,
          message: "Could not update user password.",
          changeset: changeset
        })

      {:error, reason} ->
        module.password_reset_failure(context, %ResetPasswordError{
          token: reset_password_params.reset_password_token,
          message: reason
        })
    end
  end
end
