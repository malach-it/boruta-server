defmodule BorutaAdminWeb.PageController do
  use BorutaAdminWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:basic_authorization, basic_authorization?(conn))
    |> put_resp_header("cache-control", "private, no-store")
    |> put_layout(false)
    |> render("admin.html")
  end

  defp basic_authorization?(conn) do
    Enum.any?(["authorization", "x-forwarded-authorization"], fn header ->
      Enum.any?(get_req_header(conn, header), &Regex.match?(~r/\ABasic [A-Za-z0-9+\/]+=*\z/i, &1))
    end)
  end
end
