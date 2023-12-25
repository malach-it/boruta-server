defmodule BorutaGateway.ServiceRegistry.NodeConnection do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaGateway.ServiceRegistry.Node

  @type t :: %__MODULE__{
          from: String.t(),
          to: String.t(),
          status: String.t()
        }

  @status_up "up"

  def status_up, do: @status_up

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "node_connections" do
    field :status, :string

    belongs_to :from, Node, foreign_key: :from_id
    belongs_to :to, Node, foreign_key: :to_id

    timestamps()
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:from_id, :to_id, :status])
    |> validate_required([:from_id, :to_id, :status])
  end
end
