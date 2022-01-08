defmodule BorutaIdentity.Accounts.RegistrationError do
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

defmodule BorutaIdentity.Accounts.RegistrationApplication do
  @moduledoc """
  TODO RegistrationApplication documentation
  """

  @callback user_initialized(context :: any(), changeset :: Ecto.Changeset.t()) :: any()

  @callback user_registered(context :: any(), user :: BorutaIdentity.Accounts.User.t(), session_token :: String.t()) ::
              any()

  @callback registration_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.RegistrationError.t()
            ) :: any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Registrations do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientimpl: 2]

  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.User

  @type registration_params :: map()

  @callback registration_changeset(user :: User.t()) :: changeset :: Ecto.Changeset.t()

  @callback register(
              registration_params :: registration_params(),
              confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t())
            ) ::
              {:ok, user :: User.t()}
              | {:error, reason :: String.t()}
              | {:error, changeset :: Ecto.Changeset.t()}

  @spec initialize_registration(context :: any(), client_id :: String.t(), module :: atom()) ::
          callback_result :: any()
  defwithclientimpl initialize_registration(context, client_id, module) do
    changeset = apply(client_impl, :registration_changeset, [%User{}])

    module.user_initialized(context, changeset)
  end

  @spec register(
          context :: any(),
          client_id :: String.t(),
          registration_params :: registration_params(),
          confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t()),
          module :: atom()
        ) :: calback_result :: any()
  defwithclientimpl register(
                      context,
                      client_id,
                      registration_params,
                      confirmation_url_fun,
                      module
                    ) do
    with {:ok, user} <- apply(client_impl, :register, [registration_params, confirmation_url_fun]),
         {:ok, session_token} <- apply(client_impl, :create_session, [user]) do
      module.user_registered(context, user, session_token)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.registration_failure(context, %RegistrationError{
          changeset: changeset,
          message: "Could not create user with given params."
        })

      {:error, reason} ->
        module.registration_failure(context, %RegistrationError{message: reason})
    end
  end
end
