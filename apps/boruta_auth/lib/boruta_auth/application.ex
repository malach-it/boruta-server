defmodule BorutaAuth.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      BorutaAuth.Repo,
      BorutaAuth.Scheduler
    ]

    BorutaAuth.LogRotate.rotate()
    setup_database()

    opts = [strategy: :one_for_one, name: BorutaAuth.Supervisor]
    Supervisor.start_link(children, opts)
  end
  def setup_database do
    Enum.each([BorutaAuth.Repo], fn repo ->
      repo.__adapter__.storage_up(repo.config)
    end)

    :ok
  end
end
