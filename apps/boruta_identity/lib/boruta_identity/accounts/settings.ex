defmodule BorutaIdentity.Accounts.SettingsError do
  @enforce_keys [:message]
  defexception [:message, :changeset, :template]

  @type t :: %__MODULE__{
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

defmodule BorutaIdentity.Accounts.SettingsApplication do
  @moduledoc false

  @callback edit_user_initialized(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback user_updated(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()

  @callback user_update_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.SettingsError.t()
            ) :: any()

  @callback user_destroyed(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()

  @callback user_destroy_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.SettingsError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Settings do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.SettingsError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.Repo

  @type user_update_params :: %{
          :current_password => String.t(),
          optional(:email) => String.t(),
          optional(:password) => String.t(),
          optional(:metadata) => map()
        }

  @type authentication_params :: %{
          password: String.t()
        }

  @callback update_user(
              backend :: BorutaIdentity.IdentityProviders.Backend.t(),
              impl_user :: any(),
              user_update_params :: user_update_params()
            ) ::
              {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  # NOTE emits a compilation warning since callback is already defined in BorutaIdentity.Accounts.Sessions
  # @callback check_user_against(
  #             backend :: Backend.t(),
  #             user :: User.t(),
  #             authentication_params :: authentication_params(),
  #             identity_provider :: IdentityProvider.t()
  #           ) ::
  #             {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @callback delete_user(id :: String.t()) :: :ok | {:error, reason :: String.t()}

  @spec initialize_edit_user(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          module :: atom()
        ) ::
          callback_result :: any()
  defwithclientidp initialize_edit_user(context, client_id, user, module) do
    module.edit_user_initialized(context, user, edit_user_template(client_idp))
  end

  @spec update_user(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          user_update_params :: user_update_params(),
          confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t()),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp update_user(
                     context,
                     client_id,
                     user,
                     user_update_params,
                     confirmation_url_fun,
                     module
                   ) do
    client_impl = IdentityProvider.implementation(client_idp)
    # TODO remove implementation_user from domain

    user_update_params =
      case user_update_params[:metadata] do
        %{} = metadata ->
          Map.put(
            user_update_params,
            :metadata,
            User.user_metadata_filter(user, metadata, client_idp.backend)
          )

        nil ->
          user_update_params
      end

    with {:ok, old_user} <-
           apply(client_impl, :get_user, [client_idp.backend, %{email: user.username}]),
         {:ok, _user} <-
           apply(client_impl, :check_user_against, [
             client_idp.backend,
             old_user,
             %{password: user_update_params[:current_password]}
           ]),
         # TODO wrap user update and confirmation email sending in a transaction
         {:ok, user} <-
           apply(client_impl, :update_user, [client_idp.backend, old_user, user_update_params]),
         {:ok, user} <- maybe_unconfirm_user(old_user, user, client_idp),
         :ok <-
           maybe_deliver_email_confirmation_instructions(
             client_idp.backend,
             old_user,
             user,
             confirmation_url_fun,
             client_idp
           ) do
      module.user_updated(context, user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.user_update_failure(context, %SettingsError{
          template: edit_user_template(client_idp),
          message: "Could not update user with given params.",
          changeset: changeset
        })

      {:error, reason} ->
        module.user_update_failure(context, %SettingsError{
          template: edit_user_template(client_idp),
          message: reason
        })
    end
  end

  @spec destroy_user(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          module :: atom()
        ) ::
          callback_result :: any() | {:error, reason :: String.t()} | {:error, Ecto.Changeset.t()}
  defwithclientidp destroy_user(context, client_id, user, module) do
    client_impl = IdentityProvider.implementation(client_idp)

    with :ok <- apply(client_impl, :delete_user, [user.uid]),
         {:ok, user} <- Repo.delete(user) do
      module.user_destroyed(context, user)
    else
      {:error, _error} ->
        module.user_destroy_failure(context, %SettingsError{
          template: edit_user_template(client_idp),
          message: "User could not be deleted, please contact an administrator.",
        })
    end
  end

  defp maybe_unconfirm_user(old_user, user, %IdentityProvider{confirmable: true}) do
    case email_changed?(old_user, user) do
      true -> User.unconfirm_changeset(user) |> Repo.update()
      false -> {:ok, user}
    end
  end

  defp maybe_unconfirm_user(_old_user, user, %IdentityProvider{confirmable: false}) do
    {:ok, user}
  end

  defp maybe_deliver_email_confirmation_instructions(
         _backend,
         _old_user,
         _user,
         _confirmation_url_fun,
         %IdentityProvider{confirmable: false}
       ) do
    :ok
  end

  defp maybe_deliver_email_confirmation_instructions(
         backend,
         old_user,
         user,
         confirmation_url_fun,
         %IdentityProvider{confirmable: true}
       ) do
    case email_changed?(old_user, user) do
      true ->
        with {:ok, _confirmation_token} <-
               Deliveries.deliver_user_confirmation_instructions(
                 backend,
                 user,
                 confirmation_url_fun
               ) do
          :ok
        end

      false ->
        :ok
    end
  end

  defp email_changed?(%{email: email}, %User{username: email}), do: false
  defp email_changed?(%{email: _email}, %User{username: nil}), do: false
  defp email_changed?(_user, _user_update_params), do: true

  defp edit_user_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :edit_user)
  end
end
