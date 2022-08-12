defmodule BorutaIdentity.Accounts.RegistrationError do
  @enforce_keys [:message]
  defexception [:user, :message, :changeset, :template]

  @type t :: %__MODULE__{
          user: BorutaIdentity.Accounts.User.t() | nil,
          message: String.t(),
          changeset: Ecto.Changeset.t() | nil,
          template: BorutaIdentity.IdentityProviders.Template.t()
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
              template :: BorutaIdentity.IdentityProviders.Template.t()
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
end

defmodule BorutaIdentity.Accounts.Registrations do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @type registration_params :: map()

  @callback register(registration_params :: registration_params()) ::
              {:ok, user :: User.t()}
              | {:error, changeset :: Ecto.Changeset.t()}

  @spec initialize_registration(context :: any(), client_id :: String.t(), module :: atom()) ::
          callback_result :: any()
  defwithclientidp initialize_registration(context, client_id, module) do
    module.registration_initialized(context, new_registration_template(client_idp))
  end

  @spec register(
          context :: any(),
          client_id :: String.t(),
          registration_params :: registration_params(),
          confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t()),
          module :: atom()
        ) :: calback_result :: any()
  defwithclientidp register(
                    context,
                    client_id,
                    registration_params,
                    confirmation_url_fun,
                    module
                  ) do
    client_impl = IdentityProvider.implementation(client_idp)

    with {:ok, user} <-
           apply(client_impl, :register, [registration_params]),
         :ok <- maybe_deliver_confirmation_email(user, confirmation_url_fun, client_idp),
         {:ok, user, session_token} <- maybe_create_session(user, client_idp) do
      # TODO do not log in user if confirmable is set
      module.user_registered(context, user, session_token)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.registration_failure(context, %RegistrationError{
          changeset: changeset,
          message: "Could not create user with given params.",
          template: new_registration_template(client_idp)
        })

      {:user_not_confirmed, user, reason} ->
        module.registration_failure(context, %RegistrationError{
          user: user,
          message: reason,
          template: new_confirmation_instructions_template(client_idp)
        })
    end
  end

  defp maybe_deliver_confirmation_email(_user, _confirmation_url_fun, %IdentityProvider{
         confirmable: false
       }) do
    :ok
  end

  defp maybe_deliver_confirmation_email(user, confirmation_url_fun, %IdentityProvider{
         confirmable: true
       }) do
    with {:ok, _confirmation_token} <-
           Deliveries.deliver_user_confirmation_instructions(
             user,
             confirmation_url_fun
           ) do
      :ok
    end
  end

  defp maybe_create_session(user, %IdentityProvider{confirmable: true}) do
    {:user_not_confirmed, user, "Email confirmation is required to authenticate."}
  end

  defp maybe_create_session(user, %IdentityProvider{confirmable: false}) do
    Sessions.create_user_session(user)
  end

  defp new_registration_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration)
  end

  defp new_confirmation_instructions_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_confirmation_instructions)
  end
end
