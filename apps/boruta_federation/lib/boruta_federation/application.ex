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

    setup_database()
    Supervisor.start_link(children, opts)
  end

  def setup_database do
    Enum.each([BorutaFederation.Repo], fn repo ->
      repo.__adapter__.storage_up(repo.config)
    end)

    Enum.each([BorutaFederation.Repo], fn repo ->
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)

    :ok
  end

  @impl true
  def config_change(changed, _new, removed) do
    BorutaFederationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
