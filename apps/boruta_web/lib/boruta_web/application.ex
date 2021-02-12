defmodule BorutaWeb.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      BorutaWeb.Endpoint,
      BorutaWeb.Repo,
      BorutaWeb.Metrics,
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies), [name: BorutaWeb.ClusterSupervisor]]},
      {Phoenix.PubSub, name: BorutaWeb.PubSub}
    ]

    opts = [strategy: :one_for_one, name: BorutaWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BorutaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
