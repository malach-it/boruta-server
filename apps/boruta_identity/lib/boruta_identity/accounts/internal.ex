defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """

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
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.Repo

  @impl BorutaIdentity.Accounts.Registrations
  def register(registration_params, confirmation_url_fun, opts) do
    case create_user(registration_params, confirmation_url_fun, opts) do
      {:ok, %{create_user: user}} ->
        {:ok, user}

      {:error, :create_user, changeset, _changes} ->
        {:error, changeset}

      {:error, :deliver_confirmation_mail, reason, %{create_user: user}} ->
        changeset =
          user
          |> Map.delete(:__meta__)
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:confirmation_email, reason)

        {:error, %{changeset | action: :insert}}
    end
  end

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(%{email: email}) when is_binary(email) do
    user =
      Repo.one!(
        from(u in Internal.User,
          left_join: as in assoc(u, :authorized_scopes),
          where: u.email == ^email,
          preload: [authorized_scopes: as]
        )
      )

    {:ok, user}
  rescue
    Ecto.NoResultsError ->
      {:error, "User not found."}
  end

  def get_user(_authentication_params), do: {:error, "Cannot find an user without an email."}

  @impl BorutaIdentity.Accounts.Sessions
  def domain_user!(user) do
    struct(User, Map.from_struct(user))
  end

  @impl true # BorutaIdentity.Accounts.Sessions, BorutaIdentity.Accounts.Settings
  def check_user_against(user, authentication_params, %RelyingParty{confirmable: false}) do
    check_user_password(user, authentication_params[:password])
  end

  def check_user_against(user, authentication_params, %RelyingParty{confirmable: true}) do
    with {:ok, user} <- check_user_password(user, authentication_params[:password]) do
      check_user_confirmed(user)
    end
  end

  defp check_user_password(user, password) do
    case Internal.User.valid_password?(user, password) do
      true -> {:ok, user}
      false -> {:error, "Invalid user password."}
    end
  end

  defp check_user_confirmed(user) do
    case Internal.User.confirmed?(user) do
      true -> {:ok, user}
      false -> {:user_not_confirmed, "Email confirmation is required to authenticate."}
    end
  end

  @impl BorutaIdentity.Accounts.Sessions
  def create_session(user) do
    with {:ok, user} <- Internal.User.login_changeset(user) |> Repo.update(),
         {_token, user_token} = UserToken.build_session_token(user),
         {:ok, session_token} <- Repo.insert(user_token) do
      {:ok, session_token.token}
    end
  end

  @impl BorutaIdentity.Accounts.Sessions
  def delete_session(nil), do: {:error, "Session not found."}

  def delete_session(session_token) do
    case Repo.delete_all(UserToken.token_and_context_query(session_token, "session")) do
      {1, _} -> :ok
      {_, _} -> {:error, "Session not found."}
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
  def send_confirmation_instructions(user, confirmation_url_fun) do
    with {:ok, _email} <-
           Deliveries.deliver_user_confirmation_instructions(
             domain_user!(user),
             confirmation_url_fun
           ) do
      :ok
    end
  end

  @impl BorutaIdentity.Accounts.Confirmations
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %Internal.User{confirmed_at: nil} = user <- Repo.one(query),
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
    user
    |> Internal.User.update_changeset(params)
    |> Repo.update()
  end

  defp create_user(registration_params, confirmation_url_fun, opts) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:create_user, fn _changes ->
      Internal.User.registration_changeset(%Internal.User{}, registration_params)
    end)
    |> deliver_confirmation_email(confirmation_url_fun, opts[:confirmable?])
    |> Repo.transaction()
  end

  defp deliver_confirmation_email(multi, _confirmation_url_fun, false), do: multi

  defp deliver_confirmation_email(multi, confirmation_url_fun, true) do
    Ecto.Multi.run(multi, :deliver_confirmation_mail, fn _repo, %{create_user: user} ->
      Deliveries.deliver_user_confirmation_instructions(
        domain_user!(user),
        confirmation_url_fun
      )
    end)
  end

  defp get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %Internal.User{} = user <- Repo.one(query) do
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
    |> Ecto.Multi.update(:user, Internal.User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end
end
