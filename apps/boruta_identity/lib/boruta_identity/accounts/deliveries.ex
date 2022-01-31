defmodule BorutaIdentity.Accounts.Deliveries do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserNotifier
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @type callback_function :: (token :: String.t() -> String.t())

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_update_email_instructions(
          user :: User.t(),
          current_email :: String.t(),
          update_email_url_fun :: callback_function()
        ) :: any()
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
  @spec deliver_user_confirmation_instructions(
          user :: User.t(),
          confirmation_url_fun :: callback_function()
        ) :: any()
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    # TODO move logic to BorutaIdentity.Accounts.Internal
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")

      with {:ok, _user_token} <- Repo.insert(user_token),
           {:ok, _email} <-
             UserNotifier.deliver_confirmation_instructions(
               user,
               confirmation_url_fun.(encoded_token)
             ) |> UserNotifier.deliver() do
        {:ok, encoded_token}
      end
    end
  end

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_reset_password_instructions(
          user :: User.t(),
          reset_password_url_fun :: callback_function()
        ) :: {:ok, %UserToken{}} | {:error, reason :: any()}
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")

    with {:ok, _user_token} <- Repo.insert(user_token),
         {:ok, _email} <-
           UserNotifier.deliver_reset_password_instructions(
             user,
             reset_password_url_fun.(encoded_token)
           )
           |> UserNotifier.deliver() do
      {:ok, encoded_token}
    end
  end
end
