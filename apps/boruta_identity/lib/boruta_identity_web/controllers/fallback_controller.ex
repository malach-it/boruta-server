defmodule BorutaIdentityWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.ErrorHelpers

  alias BorutaIdentityWeb.ChangesetView
  alias BorutaIdentityWeb.ErrorView

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors_message = changeset |> ChangesetView.translate_errors() |> errors_tag()

    conn
    |> put_flash(:error, errors_message)
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render(:"404")
  end
end
