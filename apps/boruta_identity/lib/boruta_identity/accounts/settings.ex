defmodule BorutaIdentity.Accounts.SettingsError do
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

defmodule BorutaIdentity.Accounts.SettingsApplication do
  @moduledoc false

  @callback edit_user_initialized(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

  @callback user_updated(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t()
            ) :: any()

  @callback user_update_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.SettingsError.t()
            ) :: any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Settings do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts.SettingsError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.Repo

  @type user_update_params :: map()

  @type authentication_params :: %{
          password: String.t()
        }

  @callback update_user(user :: User.t(), user_update_params :: user_update_params()) ::
              {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  # NOTE emits a compilation warning since callback is already defined in BorutaIdentity.Accounts.Sessions
  # @callback check_user_against(
  #             user :: User.t(),
  #             authentication_params :: authentication_params(),
  #             relying_party :: RelyingParty.t()
  #           ) ::
  #             {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @spec initialize_edit_user(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          module :: atom()
        ) ::
          callback_result :: any()
  defwithclientrp initialize_edit_user(context, client_id, user, module) do
    module.edit_user_initialized(context, user, edit_user_template(client_rp))
  end

  @spec update_user(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          user_update_params :: user_update_params(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp update_user(context, client_id, user, user_update_params, module) do
    client_impl = RelyingParty.implementation(client_rp)

    with {:ok, _user} <-
           apply(client_impl, :check_user_against, [
             user,
             %{password: user_update_params[:current_password]},
             client_rp
           ]),
         {:ok, user} <- apply(client_impl, :update_user, [user, user_update_params]) do
      module.user_updated(context, user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.user_update_failure(context, %SettingsError{
          template: edit_user_template(client_rp),
          message: "Could not update user with given params.",
          changeset: changeset
        })

      {:error, reason} ->
        module.user_update_failure(context, %SettingsError{
          template: edit_user_template(client_rp),
          message: reason
        })
    end
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  @spec update_user_email(user :: User.t(), token :: String.t()) :: :ok | :error
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  defp edit_user_template(relying_party) do
    RelyingParties.get_relying_party_template!(relying_party.id, :edit_user)
  end
end
