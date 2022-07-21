defmodule BorutaAdminWeb.LogsController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization, only: [
    authorize: 2
  ]

  alias BorutaAdmin.Logs

  plug :authorize, ["logs:read:all"]

  def index(conn, _params) do
    log_stream = Logs.read(Date.utc_today())

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    Enum.reduce_while(log_stream, conn, fn chunk, conn ->
      case Plug.Conn.chunk(conn, chunk) do
        {:ok, conn} ->
          {:cont, conn}

        {:error, :closed} ->
          {:halt, conn}
      end
    end)
  end
end
