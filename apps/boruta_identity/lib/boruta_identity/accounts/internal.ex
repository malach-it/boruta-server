defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """

  @behaviour BorutaIdentity.Accounts

  import Ecto.Query, only: [from: 2]

  alias BorutaIdentity.Accounts.Internal

  @impl BorutaIdentity.Accounts
  defdelegate registration_changeset(user), to: Internal.Registrations

  @impl BorutaIdentity.Accounts
  defdelegate register(user_params, confirmation_url_fun), to: Internal.Registrations

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @impl BorutaIdentity.Accounts
  def get_user(%{email: email}) when is_binary(email) do
    user =
      Repo.one!(
        from u in User,
          left_join: as in assoc(u, :authorized_scopes),
          where: u.email == ^email,
          preload: [authorized_scopes: as]
      )

    {:ok, user}
  rescue
    Ecto.NoResultsError ->
      {:error, "User not found."}
  end

  def get_user(_authentication_params), do: {:error, "Cannot find an user without an email."}

  @impl BorutaIdentity.Accounts
  def check_user_against(user, authentication_params) do
    case User.valid_password?(user, authentication_params[:password]) do
      true -> {:ok, user}
      false -> {:error, "Provided password is invalid."}
    end
  end

  @impl BorutaIdentity.Accounts
  def create_session(user) do
    with {:ok, user} <- User.login_changeset(user) |> Repo.update(),
         {_token, user_token} = UserToken.build_session_token(user),
         {:ok, session_token} <- Repo.insert(user_token) do
      {:ok, session_token.token}
    end
  end

  @impl BorutaIdentity.Accounts
  def delete_session(nil), do: {:error, "Session not found."}
  def delete_session(session_token) do
    case Repo.delete_all(UserToken.token_and_context_query(session_token, "session")) do
      {1, _} -> :ok
      {_, _} -> {:error, "Session not found."}
    end
  end
end
