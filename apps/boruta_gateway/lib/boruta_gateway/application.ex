defmodule BorutaGateway.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias BorutaGateway.Upstreams

  def start(_type, _args) do
    children = [
      BorutaGateway.Repo,
      %{
        id: Upstreams.Store,
        start: {Upstreams.Store, :start_link, []}
      },
      %{
        id: Upstreams.Client,
        start: {Upstreams.Client, :start_link, [[pool_size: 64]]}
      }
    ]

    children =
      case Application.get_env(:boruta_gateway, :server) do
        true ->
          [
            {BorutaGateway.Server, [port: Application.fetch_env!(:boruta_gateway, :port)]}
            | children
          ]

        _ ->
          children
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: BorutaGateway.Supervisor)
  end
end
