defmodule BorutaIdentityWeb.UserSessionController do
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [log_in: 3, log_out_user: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    with %User{} = user <- Accounts.get_user_by_email(email),
         :ok <- Accounts.check_user_password(user, password) do
        log_in(conn, user, user_params)
    else
      _ ->
        render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> log_out_user()
    |> put_flash(:info, "Logged out successfully.")
  end
end
