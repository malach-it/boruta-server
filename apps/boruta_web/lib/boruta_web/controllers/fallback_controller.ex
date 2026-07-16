defmodule BorutaWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BorutaWeb, :controller

  alias Boruta.Oauth.Error

  def call(
        conn,
        {:error, %Error{status: status, error: error, error_description: error_description}}
      ) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: error_description})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(BorutaWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(BorutaWeb.ErrorView)
    |> render(:"400")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(BorutaWeb.ErrorView)
    |> render(:"404")
  end
end
