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
          optional(:password) => String.t()
        }

  @type authentication_params :: %{
          password: String.t()
        }

  @callback update_user(
              backend :: BorutaIdentity.IdentityProviders.Backend.t(),
              user :: User.t(),
              user_update_params :: user_update_params()
            ) ::
              {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  # NOTE emits a compilation warning since callback is already defined in BorutaIdentity.Accounts.Sessions
  # @callback check_user_against(
  #             user :: User.t(),
  #             authentication_params :: authentication_params(),
  #             identity_provider :: IdentityProvider.t()
  #           ) ::
  #             {:ok, user :: User.t()} | {:error, reason :: String.t()}

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
    with {:ok, old_user} <- apply(client_impl, :get_user, [%{id: user.uid}]),
         {:ok, _user} <-
           apply(client_impl, :check_user_against, [
             old_user,
             %{password: user_update_params[:current_password]}
           ]),
         # TODO wrap user update and confirmation email sending in a transaction
         {:ok, user} <-
           apply(client_impl, :update_user, [client_idp.backend, old_user, user_update_params]),
         {:ok, user} <- maybe_unconfirm_user(old_user, user, client_idp),
         :ok <-
           maybe_deliver_email_confirmation_instructions(
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
         _old_user,
         _user,
         _confirmation_url_fun,
         %IdentityProvider{confirmable: false}
       ) do
    :ok
  end

  defp maybe_deliver_email_confirmation_instructions(
         old_user,
         user,
         confirmation_url_fun,
         %IdentityProvider{confirmable: true}
       ) do
    case email_changed?(old_user, user) do
      true ->
        with {:ok, _confirmation_token} <-
               Deliveries.deliver_user_confirmation_instructions(
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
