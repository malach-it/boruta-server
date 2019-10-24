defmodule Boruta.MixProject do
  use Mix.Project

  def project do
    [
      name: "Boruta core",
      app: :boruta,
      version: "0.1.0-rc.5",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      source_url: "https://github.com/patatoid/boruta-core",
      dialyzer: [
        plt_add_apps: [:mix]
      ]
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
      {:ex_machina, "~> 2.3", only: :test},
      {:ex_json_schema, "~> 0.6.1"},
      {:secure_random, "~> 0.5"},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:puid, "~> 1.0"},
      {:pow, "~> 1.0.11"}
    ]
  end

  defp docs do
    [
      main: "Boruta",
      source_url: "https://gitlab.com/patatoid/boruta-core",
      groups_for_modules: [
        "Responses": [
          Boruta.Oauth.AuthorizeResponse,
          Boruta.Oauth.TokenResponse,
          Boruta.Oauth.IntrospectResponse
        ],
        "Authorization": [
          Boruta.Oauth.Authorization,
          Boruta.Oauth.Authorization.AccessToken,
          Boruta.Oauth.Authorization.Client,
          Boruta.Oauth.Authorization.Code,
          Boruta.Oauth.Authorization.ResourceOwner,
          Boruta.Oauth.Authorization.Scope
        ],
        "Introspection": [
          Boruta.Oauth.Introspect
        ],
        "Contexts": [
          Boruta.Oauth.AccessTokens,
          Boruta.Oauth.Clients,
          Boruta.Oauth.Codes,
          Boruta.Oauth.ResourceOwners,
          Boruta.Oauth.Scopes,
        ],
        "Schemas": [
          Boruta.Oauth.Token,
          Boruta.Oauth.Client,
          Boruta.Oauth.Scope
        ],
        "OAuth request": [
          Boruta.Oauth.TokenRequest,
          Boruta.Oauth.PasswordRequest,
          Boruta.Oauth.AuthorizationCodeRequest,
          Boruta.Oauth.ClientCredentialsRequest,
          Boruta.Oauth.CodeRequest,
          Boruta.Oauth.IntrospectRequest,
          Boruta.Oauth.RefreshTokenRequest,
          Boruta.Oauth.Request
        ],
        "Admin": [
          Boruta.Admin,
          Boruta.Admin.Clients,
          Boruta.Admin.Scopes,
          Boruta.Admin.Users
        ],
        "Utilities": [
          Boruta.BasicAuth,
          Boruta.Oauth.Validator,
          Boruta.Oauth.TokenGenerator
        ],
        "Errors": [
          Boruta.Oauth.Error
        ]
      ]
    ]
  end

  defp package do
    %{
      name: "boruta",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/patatoid/boruta-core"
      }
    }
  end

  defp description do
    """
    Boruta is the core of an OAuth provider giving business logic of authentication and authorization.
    """
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
