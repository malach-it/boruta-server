defmodule BorutaAdminWeb.LogsController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaAdmin.Logs

  @applications %{
    "boruta_admin" => :boruta_admin,
    "boruta_gateway" => :boruta_gateway,
    "boruta_identity" => :boruta_identity,
    "boruta_web" => :boruta_web
  }

  @types %{
    "business" => :business,
    "request" => :request
  }

  @query_filters %{
    "action" => :action,
    "domain" => :domain,
    "label" => :label
  }

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
         {:ok, end_at, _offset} <- DateTime.from_iso8601(end_at),
         {:ok, application} <- fetch_application(application),
         {:ok, type} <- fetch_type(type),
         {:ok, query} <- fetch_query(params["query"] || %{}) do
      query =
        query

      log_stream = Logs.read(start_at, end_at, application, type, query)

      conn
      |> render("index.json", stats: Enum.into(log_stream, %{}))
    else
      _ ->
        {:error, :bad_request}
    end
  end

  defp fetch_application(application), do: Map.fetch(@applications, application)

  defp fetch_type(type), do: Map.fetch(@types, type)

  defp fetch_query(query) do
    Enum.reduce_while(query, {:ok, %{}}, fn {key, value}, {:ok, filters} ->
      case Map.fetch(@query_filters, key) do
        {:ok, filter} -> {:cont, {:ok, Map.put(filters, filter, value)}}
        :error -> {:halt, :error}
      end
    end)
  end
end
