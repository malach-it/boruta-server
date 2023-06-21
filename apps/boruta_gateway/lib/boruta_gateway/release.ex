defmodule BorutaGateway.Release do
  @moduledoc false
  @apps [:boruta_auth, :boruta_gateway]

  def migrate do
    for repo <- repos() do
      repo.__adapter__.storage_up(repo.config)

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def load_configuration do
    Application.ensure_all_started(:boruta_gateway)

    configuration_path = Application.get_env(:boruta_gateway, :configuration_path)

    BorutaGateway.ConfigurationLoader.from_file!(configuration_path)
  end

  def rollback(repo, version) do
    repo.__adapter__.storage_up(repo.config)

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def setup do
    migrate()
  end

  defp repos do
    Enum.flat_map(@apps, fn app ->
      Application.load(app)
      Application.fetch_env!(app, :ecto_repos)
    end)
    |> Enum.uniq()
  end
end
