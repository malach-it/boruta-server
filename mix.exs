defmodule Boruta.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      version: "0.2.0",
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      aliases: aliases(),
      releases: [
        boruta: [
          include_executables_for: [:unix],
          applications: [
            boruta_web: :permanent,
            boruta_admin: :permanent,
            boruta_gateway: :permanent
          ]
        ]
      ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: "cmd mix test"
    ]
  end
end
