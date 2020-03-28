defmodule BorutaWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :boruta_web,
      version: "0.1.0",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BorutaWeb.Application, []},
      extra_applications: [:logger, :runtime_tools, :boruta_gateway]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:boruta, git: "https://gitlab.com/patatoid/boruta_auth.git"},
      {:boruta_identity_provider, in_umbrella: true},
      {:boruta_gateway, in_umbrella: true},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:phoenix, "~> 1.4.3"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:ex_machina, "~> 2.4", only: :test},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, we extend the test task to create and migrate the database.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/boruta.seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
