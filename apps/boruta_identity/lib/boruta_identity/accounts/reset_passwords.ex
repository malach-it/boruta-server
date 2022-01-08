defmodule BorutaIdentity.Accounts.ResetPasswordError do
  @enforce_keys [:message]
  defexception [:message, :changeset]

  @type t :: %__MODULE__{
          message: String.t(),
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

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.ResetPasswords do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientimpl: 2]

  alias BorutaIdentity.Accounts.User

  @type reset_password_url_fun :: (token :: String.t() -> reset_password_url :: String.t())

  @type reset_password_params :: %{
          email: String.t()
        }

  @spec send_reset_password_instructions(
          context :: any(),
          client_id :: String.t(),
          reset_password_params :: reset_password_params(),
          reset_password_url_fun :: reset_password_url_fun(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientimpl send_reset_password_instructions(
                      context,
                      client_id,
                      reset_password_params,
                      reset_password_url_fun,
                      module
                    ) do
    with {:ok, user} <- apply(client_impl, :get_user, [reset_password_params]) do
      apply(client_impl, :send_reset_password_instructions, [user, reset_password_url_fun])
    end

    # NOTE return a success either reset passowrd instructions email sent or not
    module.reset_password_instructions_delivered(context)
  end

  @callback send_reset_password_instructions(
              user :: User.t(),
              reset_password_url_fun :: reset_password_url_fun()
            ) ::
              :ok | {:error, reason :: String.t()}
end
