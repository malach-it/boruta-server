defmodule BorutaGateway.ServiceRegistry.Node do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.ServiceRegistry.NodeConnection

  @type t :: %__MODULE__{
          name: String.t(),
          ip: String.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "service_registry_nodes" do
    field :ip, :string
    field :name, :string
    field :node_name, :string
    field :status, :string, default: "up"

    has_many :connections, NodeConnection, foreign_key: :from_id

    timestamps()
  end

  @spec current() :: t()
  def current do
    # TODO update periodically node current ip from system
    ip =
      node()
      |> ip_from_name()

    name = ConfigurationLoader.node_name()

    current_node =
      Repo.get_by(__MODULE__, ip: ip) |> Repo.preload([connections: :to]) ||
        %__MODULE__{
          ip: ip,
          connections: []
        }

    %{current_node | name: name, node_name: Atom.to_string(node())}
  end

  @spec ip_from_name(name :: atom()) :: ip :: String.t()
  def ip_from_name(name) do
    name
    |> to_string()
    |> String.split("@")
    |> Enum.at(1)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:ip, :name, :node_name])
    |> validate_required([:ip, :name, :node_name])
  end

  @doc false
  def status_changeset(node, status) do
    change(node, %{status: status})
  end
end
