defmodule BorutaIdentity.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      BorutaIdentity.Repo,
      BorutaIdentityWeb.Telemetry,
      {Phoenix.PubSub, name: BorutaIdentity.PubSub},
      BorutaIdentityWeb.Endpoint,
      {Finch, name: BorutaIdentity.Finch}
    ]

    BorutaIdentity.Logger.start()
    setup_database()

    opts = [strategy: :one_for_one, name: BorutaIdentity.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BorutaIdentityWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def setup_database do
    Enum.each([BorutaAuth.Repo, BorutaIdentity.Repo], fn repo ->
      repo.__adapter__.storage_up(repo.config)
    end)

    :ok
  end
end
