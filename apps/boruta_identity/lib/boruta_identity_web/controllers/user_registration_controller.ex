defmodule BorutaIdentityWeb.UserRegistrationController do
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [log_in: 2]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    client_id = get_session(conn, :current_client_id)

    case Accounts.register(client_id, user_params) do
      {:ok, user} ->
        # TODO manage errors and move to domain
        # {:ok, _} =
        #   Accounts.deliver_user_confirmation_instructions(
        #     user,
        #     &Routes.user_confirmation_url(conn, :confirm, &1)
        #   )

        conn
        |> put_flash(:info, "User created successfully.")
        |> log_in(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
      {:error, reason} ->
        user_return_to = get_session(conn, :user_return_to)

        conn
        |> put_flash(:error, reason)
        |> redirect(to: user_return_to || "/")
    end
  end
end
