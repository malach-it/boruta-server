defmodule BorutaIdentityWeb.UserSessionController do
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [log_in: 3, log_out_user: 1]

  alias BorutaIdentity.Accounts

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      log_in(conn, user, user_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> log_out_user()
  end
end
