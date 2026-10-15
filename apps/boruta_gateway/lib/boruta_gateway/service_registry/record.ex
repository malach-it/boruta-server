defmodule BorutaGateway.ServiceRegistry.Record do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          node_name: String.t(),
          erlang_node_name: String.t() | nil,
          ip_address: String.t(),
          aliases: list(String.t()),
          certificate: String.t() | nil,
          private_key: String.t() | nil,
          configuration: map(),
          status: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "service_registry_records" do
    field(:node_name, :string)
    field(:erlang_node_name, :string)
    field(:ip_address, :string)
    field(:aliases, {:array, :string}, default: [])
    field(:certificate, :string)
    field(:private_key, :string)
    field(:configuration, :map, default: %{})
    field(:status, :string)

    timestamps()
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :node_name,
      :erlang_node_name,
      :ip_address,
      :aliases,
      :certificate,
      :private_key,
      :configuration,
      :status
    ])
    |> validate_required([:node_name, :ip_address, :status])
    |> unique_constraint(:node_name)
    |> unique_constraint([:ip_address, :node_name])
  end
end
