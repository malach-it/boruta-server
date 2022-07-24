defmodule BorutaAdminWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BorutaAdminWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(BorutaAdminWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(BorutaAdminWeb.ErrorView)
    |> render("400." <> get_format(conn))
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(BorutaAdminWeb.ErrorView)
    |> render("404." <> get_format(conn))
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(BorutaAdminWeb.ErrorView)
    |> render("401." <> get_format(conn))
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(BorutaAdminWeb.ErrorView)
    |> render("403." <> get_format(conn))
  end

  def call(conn, {:error, :protected_resource}) do
    conn
    |> put_status(:forbidden)
    |> put_view(BorutaAdminWeb.ErrorView)
    |> render("protected_resource." <> get_format(conn))
  end
end
