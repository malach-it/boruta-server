defmodule BorutaIdentity.MixProject do
  use Mix.Project

  def project do
    [
      app: :boruta_identity,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
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
      mod: {BorutaIdentity.Application, []},
      extra_applications: [:logger, :runtime_tools, :eldap]
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
      {:argon2_elixir, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:boruta_auth, in_umbrella: true},
      {:bypass, "~> 2.1.0", only: :test},
      {:ecto_sql, "~> 3.4"},
      {:ex_json_schema, "~> 0.9"},
      {:ex_machina, "~> 2.4", only: :test},
      {:finch, "~> 0.8"},
      {:gen_smtp, "~> 1.1"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:mox, "~> 1.0"},
      {:mustachex, git: "https://github.com/jui/mustachex.git"},
      {:nimble_csv, "~> 1.2"},
      {:nimble_pool, "~> 0.2"},
      {:oauth2, "~> 2.0"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:phoenix, "~> 1.6.0", override: true},
      {:phoenix_ecto, "~> 4.1"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:qr_code, "~> 3.0.0"},
      {:scrivener_ecto, "~> 2.7"},
      {:secure_random, "~> 0.5"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
