defmodule Boruta.MixProject do
  use Mix.Project

  def project do
    [
      app: :boruta,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Boruta.Application, []},
      extra_applications: [:logger, :runtime_tools]
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
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.0"},
      {:coherence, git: "https://github.com/appprova/coherence.git", branch: "upgrade-to-phoenix-1.4"},
      {:ex_machina, "~> 2.3", only: :test},
      {:ex_json_schema, "~> 0.6.0-rc.1"},
      {:secure_random, "~> 0.5"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      groups_for_modules: [
        "Authorization": [
          Boruta.Oauth.Authorization,
          Boruta.Oauth.Authorization.Base
        ],
        "Introspection": [
          Boruta.Oauth.Introspect
        ],
        "Schemas": [
          Boruta.Oauth.Token,
          Boruta.Oauth.Client
        ],
        "OAuth request": [
          Boruta.Oauth.ImplicitRequest,
          Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest,
          Boruta.Oauth.AuthorizationCodeRequest,
          Boruta.Oauth.ClientCredentialsRequest,
          Boruta.Oauth.CodeRequest,
          Boruta.Oauth.IntrospectRequest,
          Boruta.Oauth.Request
        ],
        "Utilities": [
          Boruta.BasicAuth,
          Boruta.Oauth.Validator
        ],
        "Errors": [
          Boruta.Oauth.Error
        ]
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
