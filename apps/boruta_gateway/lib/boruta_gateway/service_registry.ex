defmodule BorutaGateway.ServiceRegistry do
  @moduledoc """
  The ServiceRegistry context.
  """

  import Ecto.Query, warn: false
  alias BorutaGateway.Repo

  alias BorutaGateway.ServiceRegistry.Node

  @spec list_nodes() :: list(Node.t())
  def list_nodes do
    Repo.all(Node)
  end

  @spec current_node() :: Node.t()
  def current_node do
    Node.current()
  end

  @spec upsert_node(node :: Node.t()) :: {:ok, node :: Node.t()} | {:error, Ecto.Changeset.t()}
  def upsert_node(node) do
    Node.changeset(node, %{})
    |> Repo.insert(
      on_conflict: {:replace, [:name]},
      returning: true,
      conflict_target: [:ip]
    )
  end

  @spec delete_by_ip!(ip :: String.t()) :: :ok
  def delete_by_ip!(ip) do
    Repo.delete_all(from n in Node, where: n.ip == ^ip)

    :ok
  end
end
