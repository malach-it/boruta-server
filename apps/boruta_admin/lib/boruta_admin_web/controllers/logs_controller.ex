defmodule BorutaAdminWeb.LogsController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaAdmin.Logs

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["logs:read:all"])

  def index(
        conn,
        %{
          "start_at" => start_at,
          "end_at" => end_at,
          "application" => application,
          "type" => type
        } = params
      ) do
    with {:ok, start_at, _offset} <- DateTime.from_iso8601(start_at),
         {:ok, end_at, _offset} <- DateTime.from_iso8601(end_at) do
      query =
        (params["query"] || %{})
        |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
        |> Enum.into(%{})

      log_stream = Logs.read(start_at, end_at, String.to_atom(application), String.to_atom(type), query)

      conn
      |> render("index.json", stats: Enum.into(log_stream, %{}))
    else
      _ ->
        {:error, :bad_request}
    end
  end
end
