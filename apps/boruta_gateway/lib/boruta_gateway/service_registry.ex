defmodule BorutaGateway.ServiceRegistry do
  @moduledoc """
  The ServiceRegistry context.
  """

  import Ecto.Query, warn: false

  alias BorutaGateway.ServiceRegistry.Node
  alias BorutaGateway.ServiceRegistry.NodeConnection

  def update_current_node_routing_table do
    list_nodes()
    |> Enum.each(fn node ->
      case check_node_connection(node) do
        :ok ->
          set_node_status(node, "up")
          upsert_node_connection(current_node(), node, NodeConnection.status_up())

        {:error, reason} ->
          if node_down?(node.ip) do
            set_node_status(node, "unreachable")
          end

          upsert_node_connection(current_node(), node, reason)
      end
    end)
  end

  defp check_node_connection(to) do
    # TODO configurable healthcheck for nodes
    case :net_adm.ping(to.node_name |> String.to_atom()) do
      :pong -> :ok
      _ -> {:error, "node_unreachable"}
    end
  end

  ## Repository
  # TODO put setters / getters in a separate module
  # TODO setup cache
  # TODO connected to control pane through API
  # TODO fallback to connected nodes concensus
  alias BorutaGateway.Repo

  # database getter in schema
  @spec current_node() :: Node.t()
  def current_node do
    Node.current()
  end

  def get_node(id) do
    Repo.get(Node, id)
  end

  @spec list_nodes() :: list(Node.t())
  def list_nodes do
    Repo.all(
      from n in Node,
        left_join: c in assoc(n, :connections),
        left_join: t in assoc(c, :to),
        order_by: [asc: n.ip, asc: c.status, asc: t.ip],
        preload: [connections: {c, :to}]
    )
  end

  def node_down?(node_ip) do
    Repo.all(
      from c in NodeConnection,
        join: f in assoc(c, :from),
        join: t in assoc(c, :to),
        where: t.ip == ^node_ip and c.status == "up" and f.ip != t.ip
    )
    |> Enum.empty?()
  end

  @spec upsert_node(node :: Node.t()) :: {:ok, node :: Node.t()} | {:error, Ecto.Changeset.t()}
  def upsert_node(node) do
    Node.changeset(node, %{})
    |> Repo.insert(
      on_conflict: {:replace, [:name, :node_name]},
      returning: true,
      conflict_target: [:ip]
    )
  end

  defp upsert_node_connection(from, to, status) do
    %NodeConnection{}
    |> NodeConnection.changeset(%{
      from_id: from.id,
      to_id: to.id,
      status: status
    })
    |> Repo.insert(
      on_conflict: {:replace, [:status]},
      returning: true,
      conflict_target: [:from_id, :to_id]
    )
  end

  @spec delete_by_ip!(ip :: String.t()) :: :ok
  def delete_by_ip!(ip) do
    Repo.delete_all(from n in Node, where: n.ip == ^ip)

    :ok
  end

  def set_node_status(node, status) do
    Node.status_changeset(node, status)
    |> Repo.update()
  end
end
