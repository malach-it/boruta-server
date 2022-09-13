defmodule BorutaAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :boruta_auth,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {BorutaAuth.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:boruta, "~> 2.2.0"},
      {:logger_file_backend, "~> 0.0.13"},
      {:quantum, "~> 3.0"}
    ]
  end
end
