defmodule BorutaWeb.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      BorutaWeb.Endpoint,
      BorutaWeb.Repo
    ]

    opts = [strategy: :one_for_one, name: BorutaWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BorutaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
