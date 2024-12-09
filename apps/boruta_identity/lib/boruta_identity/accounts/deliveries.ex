defmodule BorutaIdentity.Accounts.Deliveries do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserNotifier
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @type callback_function :: (token :: String.t() -> String.t())

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

  @spec deliver_tx_code(
          backend :: Backend.t(),
          user :: User.t(),
          tx_code :: String.t()
        ) ::
          :ok
          | {:error, reason :: String.t() | Ecto.Changeset.t()}
  def deliver_tx_code(backend, %User{} = user, tx_code) do
    with {:ok, _email} <-
           UserNotifier.deliver_tx_code(
             backend,
             user,
             tx_code
           )
           |> UserNotifier.deliver(backend) do
      :ok
    end
  end
end
