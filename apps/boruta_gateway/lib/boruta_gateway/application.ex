defmodule BorutaGateway.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  alias BorutaGateway.{ConfigurationLoader, ServiceRegistry, Upstreams}

  @impl Application
  def start(_type, _args) do
    children = [
      BorutaGateway.Repo,
      %{
        id: ServiceRegistry,
        start: {ServiceRegistry, :start_link, []}
      },
      %{
        id: Upstreams.Store,
        start: {Upstreams.Store, :start_link, []}
      }
    ]

    children = children ++ enabled_node_service_child_specs()

    BorutaGateway.Logger.start()
    BorutaAuth.LogRotate.rotate()
    setup_database()
    load_configuration()
    Supervisor.start_link(children, strategy: :one_for_one, name: BorutaGateway.Supervisor)
  end

  def enabled_node_service_child_specs do
    acceptors_count = Application.get_env(:boruta_gateway, :num_acceptors, 8)

    [
      {Application.get_env(:boruta_gateway, :proxy_server, true),
       proxy_server_child_spec(acceptors_count)},
      {Application.get_env(:boruta_gateway, :https_proxy_server, true),
       https_proxy_server_child_spec(acceptors_count)},
      {Application.get_env(:boruta_gateway, :server, false),
       gateway_server_child_spec(acceptors_count)},
      {Application.get_env(:boruta_gateway, :sidecar_server, false),
       sidecar_server_child_spec(acceptors_count)},
      {Application.get_env(:boruta_gateway, :https_server, false),
       https_gateway_server_child_spec(acceptors_count)},
      {Application.get_env(:boruta_gateway, :sidecar_https_server, false),
       sidecar_https_server_child_spec(acceptors_count)}
    ]
    |> Enum.filter(fn {enabled?, _child_spec} -> enabled? end)
    |> Enum.map(fn {_enabled?, child_spec} -> child_spec end)
  end

  defp gateway_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpGateway.Server, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :port),
             match_function: &Upstreams.match/2,
             num_acceptors: num_acceptors
           ]
         ]},
      id: :server,
      type: :supervisor
    }
  end

  defp sidecar_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpGateway.Server, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :sidecar_port),
             match_function: &Upstreams.sidecar_match/2,
             num_acceptors: num_acceptors
           ]
         ]},
      id: :sidecar_server,
      type: :supervisor
    }
  end

  defp https_gateway_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpsGateway.Server, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :https_port),
             match_function: &Upstreams.match/2,
             verify_client_certificate:
               Application.get_env(:boruta_gateway, :https_verify_client_certificate, false),
             num_acceptors: num_acceptors
           ]
         ]},
      id: :https_server,
      type: :supervisor
    }
  end

  defp sidecar_https_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpsGateway.Server, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :sidecar_https_port),
             match_function: &Upstreams.sidecar_match/2,
             verify_client_certificate:
               Application.get_env(
                 :boruta_gateway,
                 :sidecar_https_verify_client_certificate,
                 false
               ),
             num_acceptors: num_acceptors
           ]
         ]},
      id: :sidecar_https_server,
      type: :supervisor
    }
  end

  defp proxy_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpProxy.Server, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :proxy_port),
             num_acceptors: num_acceptors
           ]
         ]},
      id: :proxy_server,
      type: :supervisor
    }
  end

  defp https_proxy_server_child_spec(num_acceptors) do
    %{
      start:
        {BorutaGateway.HttpProxy.HttpsServer, :start,
         [
           [
             port: Application.fetch_env!(:boruta_gateway, :https_proxy_port),
             num_acceptors: num_acceptors
           ]
         ]},
      id: :https_proxy_server,
      type: :supervisor
    }
  end

  def setup_database do
    Enum.each([BorutaGateway.Repo], fn repo ->
      repo.__adapter__().storage_up(repo.config())
    end)

    Enum.each([BorutaGateway.Repo], fn repo ->
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)

    :ok
  end

  defp load_configuration do
    with {:ok, configuration_path} <- configuration_path() do
      Logger.info("Loading gateway static configuration from #{configuration_path}")

      {:ok, _, _} =
        Ecto.Migrator.with_repo(BorutaGateway.Repo, fn _repo ->
          ConfigurationLoader.from_file!(configuration_path)
        end)
    end

    :ok
  end

  defp configuration_path do
    configuration_path = Application.get_env(:boruta_gateway, :configuration_path)
    explicit_configuration_path = System.get_env("BORUTA_GATEWAY_CONFIGURATION_PATH")

    cond do
      is_nil(configuration_path) ->
        :ignore

      File.regular?(configuration_path) ->
        {:ok, configuration_path}

      explicit_configuration_path in [nil, ""] ->
        :ignore

      true ->
        raise "gateway static configuration file does not exist: #{configuration_path}"
    end
  end
end
