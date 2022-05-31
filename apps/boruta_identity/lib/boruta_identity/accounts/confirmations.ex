defmodule BorutaIdentity.Accounts.ConfirmationError do
  @enforce_keys [:message]
  defexception [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaIdentity.Accounts.ConfirmationApplication do
  @moduledoc """
  TODO ConfirmationApplication documentation
  """

  @callback confirmation_instructions_initialized(
              context :: any(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

  @callback confirmation_instructions_delivered(context :: any()) ::
              any()

  @callback user_confirmed(context :: any(), user :: BorutaIdentity.Accounts.User.t()) ::
              any()

  @callback user_confirmation_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.ConfirmationError.t()
            ) ::
              any()
end

defmodule BorutaIdentity.Accounts.Confirmations do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.ConfirmationError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  @type confirmation_instructions_params :: %{
          email: String.t()
        }
  @type confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t())

  @callback send_confirmation_instructions(
              user :: User.t(),
              confirmation_url_fun :: confirmation_url_fun()
            ) ::
              :ok | {:error, reason :: String.t()}

  @callback confirm_user(token :: String.t()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @spec initialize_confirmation_instructions(
          context :: any(),
          client_id :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_confirmation_instructions(context, client_id, module) do
    module.confirmation_instructions_initialized(
      context,
      new_confirmation_instructions_template(client_rp)
    )
  end

  @spec send_confirmation_instructions(
          context :: any(),
          client_id :: String.t(),
          confirmation_instructions_params :: confirmation_instructions_params(),
          confirmation_url_fun :: confirmation_url_fun(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp send_confirmation_instructions(
                    context,
                    client_id,
                    confirmation_instructions_params,
                    confirmation_url_fun,
                    module
                  ) do
    client_impl = RelyingParty.implementation(client_rp)

    with %User{} = user <- Accounts.get_user_by_email(confirmation_instructions_params[:email]) do
      apply(client_impl, :send_confirmation_instructions, [user, confirmation_url_fun])
    end

    # NOTE return a success either confirmation instructions email sent or not
    module.confirmation_instructions_delivered(context)
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  @spec confirm_user(
          context :: any(),
          client_id :: String.t(),
          token :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp confirm_user(context, client_id, token, module) do
    client_impl = RelyingParty.implementation(client_rp)

    case apply(client_impl, :confirm_user, [token]) do
      {:ok, user} ->
        module.user_confirmed(context, user)

      {:error, _reason} ->
        module.user_confirmation_failure(context, %ConfirmationError{
          message: "Account confirmation token is invalid or it has expired."
        })
    end
  end

  defp new_confirmation_instructions_template(relying_party) do
    RelyingParties.get_relying_party_template!(relying_party.id, :new_confirmation_instructions)
  end
end
