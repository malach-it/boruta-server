defmodule BorutaWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BorutaWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(BorutaWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, %{invalid_client: error_description}, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(BorutaWeb.OauthView)
    |> render("error." <> get_format(conn), error: "invalid_client", error_description: error_description)
  end

  def call(conn, {:error, %{invalid_scope: error_description}, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(BorutaWeb.OauthView)
    |> render("error." <> get_format(conn), error: "invalid_scope", error_description: error_description)
  end
end
