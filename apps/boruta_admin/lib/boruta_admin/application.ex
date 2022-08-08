defmodule BorutaAdmin.Application do
  @moduledoc false

  require Logger

  use Application

  def start(_type, _args) do
    children = [
      BorutaAdmin.Repo,
      BorutaAdminWeb.Telemetry,
      {Phoenix.PubSub, name: BorutaAdmin.PubSub},
      BorutaAdminWeb.Endpoint
    ]

    :telemetry.attach(
      :boruta_admin_requests,
      [:boruta_admin, :endpoint, :stop],
      &__MODULE__.boruta_admin_request_handler/4,
      :ok
    )

    opts = [strategy: :one_for_one, name: BorutaAdmin.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BorutaAdminWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def boruta_admin_request_handler(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(
          level,
          fn ->
            %{method: method, request_path: path, status: status, state: state} = conn
            status = Integer.to_string(status)

            [
              "boruta_admin",
              ?\s,
              method,
              ?\s,
              path,
              " - ",
              connection_type(state),
              ?\s,
              status,
              " in ",
              duration(duration)
            ]
          end,
          type: :request
        )
    end
  end

  # From Phoenix.Logger
  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  defp connection_type(:set_chunked), do: "chunked"
  defp connection_type(_), do: "sent"

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end
end
