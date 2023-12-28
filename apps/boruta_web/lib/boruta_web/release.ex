defmodule BorutaWeb.Release do
  @moduledoc false
  @apps [:boruta_auth, :boruta_identity, :boruta_web]

  def migrate do
    for repo <- repos() do
      repo.__adapter__.storage_up(repo.config)

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    repo.__adapter__.storage_up(repo.config)

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    _started =
      Enum.map(@apps, fn app ->
        Application.ensure_all_started(app)
      end)

    Code.eval_file(Path.join(:code.priv_dir(:boruta_auth), "/repo/boruta.seeds.exs"))
  end

  def setup do
    migrate()
    seed()
    register_application_repl()
  end

  defp repos do
    Enum.flat_map(@apps, fn app ->
      Application.load(app)
      Application.fetch_env!(app, :ecto_repos)
    end)
    |> Enum.uniq()
  end

  @dialyzer {:no_return, register_application_repl: 0}
  defp register_application_repl do
    Finch.start_link(name: RegistrationHttp)
    Application.ensure_started(:telemetry)

    IO.puts("====================")
    IO.puts("Please provide information about boruta package usage for statistical purposes")
    IO.puts("")
    IO.puts("The owners would be thankful if you could provide those information")
    IO.puts("====================")
    company_name = Owl.IO.input(label: "Your company name:", optional: true)
    purpose = Owl.IO.input(label: "Purpose of the installation:", optional: true)

    Finch.build(
      :post,
      "https://getform.io/f/f3907bc0-8ae5-46d6-b1ec-9e4253e2e4f1",
      [{"Content-Type", "application/json"}],
      %{
        company_name: company_name,
        purpose: purpose
      } |> Jason.encode!()
    ) |> Finch.request(RegistrationHttp)
  end
end
