defmodule BorutaGateway.ServiceRegistry.Node do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaGateway.ConfigurationLoader

  @type t :: %__MODULE__{
          name: String.t(),
          ip: String.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "service_registry_nodes" do
    field :ip, :string
    field :name, :string

    timestamps()
  end

  @spec current() :: t()
  def current do
    ip =
      node()
      |> ip_from_name()

    name = ConfigurationLoader.node_name()

    %__MODULE__{name: name, ip: ip}
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
    |> cast(attrs, [:ip, :name])
    |> validate_required([:ip, :name])
  end
end
