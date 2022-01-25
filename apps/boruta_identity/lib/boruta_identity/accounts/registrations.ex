defmodule BorutaIdentity.Accounts.RegistrationError do
  @enforce_keys [:message]
  defexception [:message, :changeset, :template]

  @type t :: %__MODULE__{
          message: String.t(),
          changeset: Ecto.Changeset.t() | nil,
          template: BorutaIdentity.RelyingParties.Template.t()
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

  @callback registration_initialized(
              context :: any(),
              changeset :: Ecto.Changeset.t(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

  @callback user_registered(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t(),
              session_token :: String.t()
            ) ::
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

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties.RelyingParty

  @type registration_params :: %{
    email: String.t(),
    password: String.t()
  }

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
  defwithclientrp initialize_registration(context, client_id, module) do
    client_impl = RelyingParty.implementation(client_rp)
    changeset = apply(client_impl, :registration_changeset, [%User{}])

    module.registration_initialized(context, changeset, new_registration_template(client_rp))
  end

  @spec register(
          context :: any(),
          client_id :: String.t(),
          registration_params :: registration_params(),
          confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t()),
          module :: atom()
        ) :: calback_result :: any()
  defwithclientrp register(
                    context,
                    client_id,
                    registration_params,
                    confirmation_url_fun,
                    module
                  ) do
    client_impl = RelyingParty.implementation(client_rp)

    with {:ok, user} <-
      apply(client_impl, :register, [registration_params |> Map.put(:relying_party_id, client_rp.id), confirmation_url_fun]),
         {:ok, session_token} <- apply(client_impl, :create_session, [user]) do
      module.user_registered(context, user, session_token)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.registration_failure(context, %RegistrationError{
          changeset: changeset,
          message: "Could not create user with given params.",
          template: new_registration_template(client_rp)
        })

      {:error, reason} ->
        module.registration_failure(context, %RegistrationError{
          message: reason,
          template: new_registration_template(client_rp)
        })
    end
  end

  defp new_registration_template(relying_party) do
    RelyingParty.template(relying_party, :new_registration)
  end
end
