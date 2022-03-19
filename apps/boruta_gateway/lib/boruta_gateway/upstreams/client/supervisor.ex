defmodule BorutaGateway.Upstreams.ClientSupervisor do
  @moduledoc false

  use DynamicSupervisor

  alias BorutaGateway.Upstreams.Client
  alias BorutaGateway.Upstreams.Upstream

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init([]) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: []
    )
  end

  def start_child(upstream) do
    DynamicSupervisor.start_child(__MODULE__, {Client, upstream})
  end

  @spec client_for_upstream(upstream :: Upstream.t()) :: {:ok, pid()} | {:error, reason :: any()}
  def client_for_upstream(upstream) do
    client_name = Client.name(upstream)

    case Process.whereis(client_name) do
      nil ->
        start_child(upstream)

      pid ->
        {:ok, pid}
    end
  end

  def kill(nil), do: {:error, :not_started}
  def kill(client) do
    Process.exit(client, :shutdown)
  end
end
