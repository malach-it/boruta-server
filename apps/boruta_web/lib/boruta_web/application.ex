defmodule BorutaWeb.Application do
  @moduledoc false

  require Logger

  use Application

  def start(_type, _args) do
    children = [
      BorutaWeb.Endpoint,
      BorutaWeb.Repo,
      BorutaWeb.Plugs.RateLimit.Counter,
      %{
        id: BorutaWeb.PresentationServer,
        start: {BorutaWeb.PresentationServer, :start_link, []}
      },
      {Finch, name: FinchHttp},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies), [name: BorutaWeb.ClusterSupervisor]]},
      {Phoenix.PubSub, name: BorutaWeb.PubSub}
    ]

    BorutaWeb.Logger.start()
    setup_database()

    opts = [strategy: :one_for_one, name: BorutaWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    BorutaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def setup_database do
    Enum.each([BorutaAuth.Repo, BorutaIdentity.Repo], fn repo ->
      repo.__adapter__.storage_up(repo.config)
    end)

    need_seeding? =
      not (Ecto.Migrator.migrated_versions(BorutaAuth.Repo)
           # First BorutaAuth migration
           |> Enum.member?(20_201_129_024_828))

    Enum.each([BorutaAuth.Repo, BorutaIdentity.Repo], fn repo ->
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)

    if need_seeding? do
      seed()
    end

    :ok
  end

  defp seed do
    Code.eval_file(Path.join(:code.priv_dir(:boruta_auth), "/repo/boruta.seeds.exs"))
  end
end
