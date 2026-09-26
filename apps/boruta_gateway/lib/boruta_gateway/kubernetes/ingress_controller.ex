defmodule BorutaGateway.Kubernetes.IngressController do
  @moduledoc false

  require Logger

  use GenServer

  alias BorutaGateway.Kubernetes.Client
  alias BorutaGateway.Kubernetes.Ingress
  alias BorutaGateway.Upstreams

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    state = %{
      client: Keyword.get(opts, :client, Client),
      interval:
        Keyword.get(
          opts,
          :interval,
          Application.fetch_env!(:boruta_gateway, :kubernetes_poll_interval)
        ),
      namespace: Keyword.get(opts, :namespace, kubernetes_namespace()),
      ingress_class:
        Keyword.get(
          opts,
          :ingress_class,
          Application.get_env(:boruta_gateway, :kubernetes_ingress_class)
        ),
      node_name:
        Keyword.get(
          opts,
          :node_name,
          Application.fetch_env!(:boruta_gateway, :kubernetes_node_name)
        )
    }

    send(self(), :sync)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:sync, state) do
    sync(state)
    schedule_sync(state.interval)

    {:noreply, state}
  end

  defp sync(state) do
    with {:ok, %{"items" => ingresses}} <-
           state.client.list_ingresses(namespace: state.namespace),
         {:ok, %{"items" => services}} <- state.client.list_services(namespace: state.namespace),
         desired_upstreams <-
           Ingress.desired_upstreams(ingresses, services,
             ingress_class: state.ingress_class,
             node_name: state.node_name
           ),
         {:ok, upstreams} <-
           Upstreams.sync_managed_upstreams(Ingress.managed_by(), desired_upstreams) do
      Logger.info("Synced #{length(upstreams)} Kubernetes ingress upstreams")
    else
      {:error, reason} ->
        Logger.error("Could not sync Kubernetes ingress upstreams: #{inspect(reason)}")

      error ->
        Logger.error("Could not sync Kubernetes ingress upstreams: #{inspect(error)}")
    end
  end

  defp schedule_sync(interval) do
    Process.send_after(self(), :sync, interval)
  end

  defp kubernetes_namespace do
    case Application.get_env(:boruta_gateway, :kubernetes_namespace) do
      nil -> Client.namespace()
      "" -> Client.namespace()
      "*" -> nil
      namespace -> namespace
    end
  end
end
