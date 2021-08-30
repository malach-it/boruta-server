defmodule BorutaAdmin.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      BorutaAdmin.Repo,
      BorutaAdminWeb.Telemetry,
      {Phoenix.PubSub, name: BorutaAdmin.PubSub},
      BorutaAdminWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BorutaAdmin.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BorutaAdminWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
