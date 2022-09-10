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
              template :: BorutaIdentity.IdentityProviders.Template.t()
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

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.ConfirmationError
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.Repo

  @type confirmation_instructions_params :: %{
          email: String.t()
        }
  @type confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t())

  @spec initialize_confirmation_instructions(
          context :: any(),
          client_id :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp initialize_confirmation_instructions(context, client_id, module) do
    module.confirmation_instructions_initialized(
      context,
      new_confirmation_instructions_template(client_idp)
    )
  end

  @spec send_confirmation_instructions(
          context :: any(),
          client_id :: String.t(),
          confirmation_instructions_params :: confirmation_instructions_params(),
          confirmation_url_fun :: confirmation_url_fun(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp send_confirmation_instructions(
                     context,
                     client_id,
                     confirmation_instructions_params,
                     confirmation_url_fun,
                     module
                   ) do
    with %User{} = user <-
           Accounts.get_user_by_email(
             client_idp.backend,
             confirmation_instructions_params[:email]
           ) do
      Deliveries.deliver_user_confirmation_instructions(client_idp.backend, user, confirmation_url_fun)
    end

    # NOTE return a success either confirmation instructions email sent or not
    module.confirmation_instructions_delivered(context)
  end

  # NOTE If the token matches, the user account is marked as confirmed and the token is deleted.
  @spec confirm_user(
          context :: any(),
          client_id :: String.t(),
          token :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  def confirm_user(context, _client_id, token, module) do
    case confirm_user(token) do
      {:ok, user} ->
        module.user_confirmed(context, user)

      {:error, _reason} ->
        module.user_confirmation_failure(context, %ConfirmationError{
          message: "Account confirmation token is invalid or it has expired."
        })
    end
  end

  defp new_confirmation_instructions_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(
      identity_provider.id,
      :new_confirmation_instructions
    )
  end

  defp confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{confirmed_at: nil} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ ->
        {:error, "Account confirmation token is invalid or it has expired."}
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end
end
