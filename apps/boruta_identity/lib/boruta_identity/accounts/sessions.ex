defmodule BorutaIdentity.Accounts.Sessions do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(user :: User.t()) :: token :: String.t()
  def generate_user_session_token(user) do
    User.login_changeset(user) |> Repo.update()

    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_session_token(token :: String.t()) :: :ok
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end
end