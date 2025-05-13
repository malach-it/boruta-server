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
                {BorutaGateway.Gateway, :start,
                 [
                   [
                     port: Application.fetch_env!(:boruta_gateway, :port),
                     num_acceptors: 10
                   ]
                 ]},
              id: :server
            }
            | children
          ]

        _ ->
          children
      end

    setup_database()
    Supervisor.start_link(children, strategy: :one_for_one, name: BorutaGateway.Supervisor, shutdown: 5_000)
  end

  def setup_database do
    Enum.each([BorutaGateway.Repo], fn repo ->
      repo.__adapter__.storage_up(repo.config)
    end)

    Enum.each([BorutaGateway.Repo], fn repo ->
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)

    :ok
  end
end
