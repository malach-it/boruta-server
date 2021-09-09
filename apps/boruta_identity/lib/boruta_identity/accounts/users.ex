defmodule BorutaIdentity.Accounts.Users do
  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @doc """
  List all users

  ## Examples

      iex> list_users()
      [...]
  """
  def list_users do
    Repo.all(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        preload: [authorized_scopes: as]
      )
    )
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def check_password(user, password)
      when is_binary(password) do
    case User.valid_password?(user, password) do
      true -> :ok
      false -> {:error, "Invalid password."}
    end
  end

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  def get_user(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        preload: [authorized_scopes: as],
        where: u.id == ^id
      )
    )
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        preload: [authorized_scopes: as],
        where: u.id == ^id
      )
    )
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def get_user_scopes(user_id) do
    Repo.all(from(u in UserAuthorizedScope, where: u.user_id == ^user_id))
  end
end
