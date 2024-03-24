defmodule BorutaWeb.Application do
  @moduledoc false

  require Logger

  use Application

  def start(_type, _args) do
    children = [
      BorutaWeb.Endpoint,
      BorutaWeb.Repo,
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
      register_application_repl()
    end

    :ok
  end

  defp seed do
    Code.eval_file(Path.join(:code.priv_dir(:boruta_auth), "/repo/boruta.seeds.exs"))
  end

  defp register_application_repl do
    Finch.start_link(name: RegistrationHttp)
    Application.ensure_started(:telemetry)

    IO.puts("====================")
    IO.puts("Please provide information about boruta package usage for statistical purposes")
    IO.puts("")
    IO.puts("These informations are optional, that said,")
    IO.puts("the owners would be thankful if you could provide those information")
    IO.puts("")
    IO.puts("Thank you for using boruta")
    IO.puts("====================")
    company_name = Owl.IO.input(label: "Your company name:", optional: true)
    purpose = Owl.IO.input(label: "Purpose of the installation:", optional: true)

    Finch.build(
      :post,
      "https://gateway.boruta.patatoid.fr/store",
      [{"Content-Type", "application/json"}],
      %{
        company_name: company_name,
        purpose: purpose
      }
      |> Jason.encode!()
    )
    |> Finch.request(RegistrationHttp)
  end
end
