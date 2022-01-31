defmodule BorutaIdentity.Accounts.ConfirmationApplication do
  @moduledoc """
  TODO ConfirmationApplication documentation
  """

  @callback confirmation_instructions_initialized(
              context :: any(),
              relying_party :: BorutaIdentity.RelyingParties.RelyingParty.t(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

  @callback confirmation_instructions_delivered(context :: any()) ::
              any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Confirmations do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.Repo

  @type confirmation_instructions_params :: %{
          email: String.t()
        }
  @type confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t())

  @callback send_confirmation_instructions(
              user :: User.t(),
              confirmation_url_fun :: confirmation_url_fun()
            ) ::
              :ok | {:error, reason :: String.t()}

  @spec initialize_confirmation_instructions(
          context :: any(),
          client_id :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_confirmation_instructions(context, client_id, module) do
    module.confirmation_instructions_initialized(
      context,
      client_rp,
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

    with {:ok, user} <- apply(client_impl, :get_user, [confirmation_instructions_params]) do
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
  @spec confirm_user(token :: String.t()) :: {:ok, user :: User.t()} | :error
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  defp new_confirmation_instructions_template(relying_party) do
    RelyingParty.template(relying_party, :new_confirmation_instructions)
  end
end
