defmodule BorutaGateway.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias BorutaGateway.Logger
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.ClientSupervisor

  def start(_type, _args) do
    children = [
      BorutaGateway.Repo,
      %{
        id: Upstreams.Store,
        start: {Upstreams.Store, :start_link, []}
      },
      {ClientSupervisor, strategy: :one_for_one}
    ]

    Logger.start()

    children =
      case Application.get_env(:boruta_gateway, :server) do
        true ->
          [
            %{
              start:
                {BorutaGateway.Server, :start_link,
                 [
                   [
                     port: Application.fetch_env!(:boruta_gateway, :port),
                     router: BorutaGateway.Router
                   ]
                 ]},
              id: :server
            }
            | children
          ]

        _ ->
          children
      end

    children =
      case Application.get_env(:boruta_gateway, :sidecar_server) do
        true ->
          [
            %{
              start:
                {BorutaGateway.Server, :start_link,
                 [
                   [
                     port: Application.fetch_env!(:boruta_gateway, :sidecar_port),
                     router: BorutaGateway.SidecarRouter
                   ]
                 ]},
              id: :sidecar_server
            }
            | children
          ]

        _ ->
          children
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: BorutaGateway.Supervisor)
  end
end
