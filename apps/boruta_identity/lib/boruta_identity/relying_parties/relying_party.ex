defmodule BorutaIdentity.RelyingParties.RelyingParty do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.ClientRelyingParty

  @type t :: %__MODULE__{
    name: String.t(),
    type: String.t(),
    client_relying_parties: list(ClientRelyingParty.t()) | Ecto.AssociationNotLoaded.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @types [
    "internal"
  ]

  @implementations %{
    "internal" => BorutaIdentity.Accounts.Internal
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "relying_parties" do
    field :name, :string
    field :type, :string

    has_many :client_relying_parties, ClientRelyingParty

    timestamps()
  end

  @spec implementation(client_relying_party :: %__MODULE__{}) :: implementation :: atom()
  def implementation(%__MODULE__{type: type}) do
    Map.fetch!(@implementations, type)
  end

  @doc false
  def changeset(relying_party, attrs) do
    relying_party
    |> cast(attrs, [:name, :type])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @types)
  end
end
