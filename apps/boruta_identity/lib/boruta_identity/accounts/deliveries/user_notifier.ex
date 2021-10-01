defmodule BorutaIdentity.Accounts.UserNotifier do
  @moduledoc false

  require Logger

  import Swoosh.Email

  alias BorutaIdentity.Mailer

  def deliver(email) do
    with {:ok, _} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """

    Logger.debug(body)
    {:ok, %{to: user.email, body: body}}
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    new()
    |> to(user.email)
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

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    Logger.debug(body)
    {:ok, %{to: user.email, body: body}}
  end
end
