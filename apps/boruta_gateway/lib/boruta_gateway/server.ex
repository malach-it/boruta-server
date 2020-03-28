defmodule BorutaGateway.Server do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: BorutaGateway.Server)
  end

  @impl Supervisor
  def init(args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: BorutaGateway.Router, options: [
        port: args[:port],
        ip: {0, 0, 0, 0},
        transport_options: [
          num_acceptors: 64
        ]
      ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
