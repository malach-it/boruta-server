defmodule BorutaAdminWeb.LogsController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization, only: [
    authorize: 2
  ]

  alias BorutaAdmin.Logs

  action_fallback BorutaAdminWeb.FallbackController

  plug :authorize, ["logs:read:all"]

  def index(conn, %{"start_at" => start_at, "end_at" => end_at}) do
    with {:ok, start_at, _offset} <- DateTime.from_iso8601(start_at),
         {:ok, end_at, _offset} <- DateTime.from_iso8601(end_at) do
      log_stream = Logs.read(start_at, end_at)

      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)
      |> stream(log_stream)
    else
      _ ->
        {:error, :bad_request}
    end
  end

  defp stream(conn, log_stream) do
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
