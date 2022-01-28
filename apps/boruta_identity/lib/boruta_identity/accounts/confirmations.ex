defmodule BorutaIdentity.Accounts.ConfirmationApplication do
  @moduledoc """
  TODO ConfirmationApplication documentation
  """

  @callback confirmation_instructions_initialized(
              context :: any(),
              relying_party :: BorutaIdentity.RelyingParties.RelyingParty.t(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

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

  defwithclientrp initialize_confirmation_instructions(context, client_id, module) do
    module.confirmation_instructions_initialized(
      context,
      client_rp,
      new_confirmation_instructions_template(client_rp)
    )
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
