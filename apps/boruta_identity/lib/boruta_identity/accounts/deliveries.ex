defmodule BorutaIdentity.Accounts.Deliveries do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserNotifier
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @type callback_function :: (token :: String.t() -> String.t())

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:error, "User is already confirmed."}

  """
  @spec deliver_user_confirmation_instructions(
          backend :: Backend.t(),
          user :: User.t(),
          confirmation_url_fun :: callback_function()
        ) ::
          {:ok, confirmation_token :: String.t()}
          | {:error, reason :: String.t() | Ecto.Changeset.t()}
  def deliver_user_confirmation_instructions(backend, %User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, "User is already confirmed."}
    else
      {encoded_token, confirmation_token} = UserToken.build_email_token(user, "confirm")

      with {:ok, _confirmation_token} <- Repo.insert(confirmation_token),
           {:ok, _email} <-
             UserNotifier.deliver_confirmation_instructions(
               backend,
               user,
               confirmation_url_fun.(encoded_token)
             )
             |> UserNotifier.deliver(backend) do
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
          backend :: Backend.t(),
          user :: User.t(),
          reset_password_url_fun :: callback_function()
        ) :: {:ok, email :: any()} | {:error, reason :: any()}
  def deliver_user_reset_password_instructions(backend, %User{} = user, reset_password_url) do
    UserNotifier.deliver_reset_password_instructions(
      backend,
      user,
      reset_password_url
    )
    |> UserNotifier.deliver(backend)
  end
end
