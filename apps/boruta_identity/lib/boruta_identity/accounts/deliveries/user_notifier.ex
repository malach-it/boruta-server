defmodule BorutaIdentity.Accounts.UserNotifier do
  # TODO replace from attribute in all mails
  @moduledoc false

  require Logger

  import Swoosh.Email

  alias BorutaIdentity.Mailer

  # TODO hide Swoosh from the rest of the world
  @spec deliver(email :: %Swoosh.Email{}) ::
          {:ok, email :: %Swoosh.Email{}} | {:error, reason :: String.t()}
  def deliver(email) do
    case Mailer.deliver(email) do
      {:ok, _} ->
        {:ok, email}

      {:error, {_status, %{"Errors" => errors}}} ->
        reason =
          errors
          |> Enum.map(fn %{"ErrorMessage" => message} -> message end)
          |> Enum.join(", ")

        {:error, reason}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.username},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """

    new()
    |> to(user.username)
    |> from("io.pascal.knoth@gmail.com")
    |> subject("Confirm your account.")
    |> text_body(body)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.username},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    new()
    |> to(user.username)
    |> from("io.pascal.knoth@gmail.com")
    |> subject("Reset your password.")
    |> text_body(body)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.username},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    Logger.debug(body)
    {:ok, %{to: user.username, body: body}}
  end
end
