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
    "label" => :label,
    "method" => :method,
    "resource_id" => :resource_id,
    "status_code" => :status_code,
    "sub" => :sub
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
    with {:ok, end_at, _offset} <- DateTime.from_iso8601(end_at),
         {:ok, application} <- fetch_application(application),
         {:ok, type} <- fetch_type(type),
         {:ok, start_at} <- fetch_start_at(start_at, application, type),
         {:ok, query} <- fetch_query(params["query"] || %{}) do
      stats =
        start_at
        |> Logs.read(end_at, application, type, query)
        |> Enum.into(%{})
        |> select_stats(type, params["events_only"])

      conn
      |> render("index.json", stats: stats)
    else
      _ ->
        {:error, :bad_request}
    end
  end

  defp fetch_application(application), do: Map.fetch(@applications, application)

  defp fetch_type(type), do: Map.fetch(@types, type)

  defp fetch_start_at("all", application, type), do: {:ok, Logs.earliest_at(application, type)}

  defp fetch_start_at(start_at, _application, _type) do
    case DateTime.from_iso8601(start_at) do
      {:ok, start_at, _offset} -> {:ok, start_at}
      _ -> :error
    end
  end

  defp select_stats(stats, :business, events_only) when events_only in [true, "true"] do
    Map.take(stats, [:events, :log_count, :overflow])
  end

  defp select_stats(stats, :business, _events_only), do: Map.delete(stats, :events)
  defp select_stats(stats, _type, _events_only), do: stats

  defp fetch_query(query) do
    Enum.reduce_while(query, {:ok, %{}}, fn {key, value}, {:ok, filters} ->
      case Map.fetch(@query_filters, key) do
        {:ok, filter} -> {:cont, {:ok, Map.put(filters, filter, value)}}
        :error -> {:halt, :error}
      end
    end)
  end
end
