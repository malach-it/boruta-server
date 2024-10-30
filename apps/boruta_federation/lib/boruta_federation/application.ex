defmodule BorutaFederation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BorutaFederation.Repo,
      BorutaFederationWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BorutaFederation.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BorutaFederationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
