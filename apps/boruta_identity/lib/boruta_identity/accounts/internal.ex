defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """

  # TODO split into multiple submodule
  @behaviour BorutaIdentity.Admin
  @behaviour BorutaIdentity.Accounts.Confirmations
  @behaviour BorutaIdentity.Accounts.Registrations
  @behaviour BorutaIdentity.Accounts.ResetPasswords
  @behaviour BorutaIdentity.Accounts.Sessions
  @behaviour BorutaIdentity.Accounts.Settings

  import Ecto.Query, only: [from: 2]

  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @impl BorutaIdentity.Accounts.Registrations
  def register(registration_params) do
    with {:ok, user} <-
           Internal.User.registration_changeset(%Internal.User{}, registration_params)
           |> Repo.insert() do
      {:ok, domain_user!(user)}
    end
  end

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(%{id: id}) when is_binary(id) do
    user = Repo.get_by!(Internal.User, id: id)

    {:ok, user}
  rescue
    Ecto.NoResultsError ->
      {:error, "User not found."}
  end

  def get_user(%{email: email}) when is_binary(email) do
    user = Repo.get_by!(Internal.User, email: email)

    {:ok, user}
  rescue
    Ecto.NoResultsError ->
      {:error, "User not found."}
  end

  def get_user(_authentication_params), do: {:error, "Cannot find an user without an email."}

  @impl BorutaIdentity.Accounts.Sessions
  def domain_user!(%Internal.User{id: id, email: email}) do
    User.implementation_changeset(%{
      uid: id,
      username: email,
      provider: to_string(__MODULE__)
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:username]},
      returning: true,
      conflict_target: [:provider, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents])
  end

  # BorutaIdentity.Accounts.Sessions, BorutaIdentity.Accounts.Settings
  @impl true
  def check_user_against(user, authentication_params) do
    check_user_password(user, authentication_params[:password])
  end

  defp check_user_password(user, password) do
    case Internal.User.valid_password?(user, password) do
      true -> {:ok, user}
      false -> {:error, "Invalid user password."}
    end
  end

  @impl BorutaIdentity.Accounts.ResetPasswords
  def send_reset_password_instructions(user, reset_password_url_fun) do
    with {:ok, _email} <-
           Deliveries.deliver_user_reset_password_instructions(
             user,
             reset_password_url_fun
           ) do
      :ok
    end
  end

  @impl BorutaIdentity.Accounts.ResetPasswords
  def reset_password_changeset(token) do
    with {:ok, user} <-
           get_user_by_reset_password_token(token) do
      {:ok, Internal.User.password_changeset(user, %{})}
    end
  end

  @impl BorutaIdentity.Accounts.ResetPasswords
  def reset_password(reset_password_params) do
    with {:ok, user} <-
           get_user_by_reset_password_token(reset_password_params.reset_password_token),
         {:ok, %{user: user}} <- reset_user_password_multi(user, reset_password_params) do
      {:ok, user}
    else
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, _reason} = error -> error
    end
  end

  @impl BorutaIdentity.Accounts.Confirmations
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{confirmed_at: nil} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ ->
        {:error, "Account confirmation token is invalid or it has expired."}
    end
  end

  @impl BorutaIdentity.Accounts.Settings
  def update_user(user, params) do
    # TODO manage email confirmation
    with {:ok, user} <-
           user
           |> Internal.User.update_changeset(params)
           |> Repo.update() do
      {:ok, domain_user!(user)}
    end
  end

  @impl BorutaIdentity.Admin
  def create_user(params) do
    with {:ok, user} <-
           Internal.User.registration_changeset(%Internal.User{}, %{
             email: params[:username],
             password: params[:password]
           }) |> Repo.insert() do
      {:ok, domain_user!(user)}
    end
  end

  @impl BorutaIdentity.Admin
  def delete_user(user_id) do
    case Repo.delete_all(from(u in Internal.User, where: u.id == ^user_id)) do
      {1, nil} -> :ok
      _ -> {:error, "User could not be deleted."}
    end
  end

  defp get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query),
         %Internal.User{} = user <- Repo.get(Internal.User, user.uid) do
      {:ok, user}
    else
      _ -> {:error, "Given reset password token is invalid."}
    end
  end

  defp reset_user_password_multi(user, reset_password_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, Internal.User.password_changeset(user, reset_password_params))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end
end
