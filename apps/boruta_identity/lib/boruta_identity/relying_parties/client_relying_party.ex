defmodule BorutaIdentity.RelyingParties.ClientRelyingParty do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.RelyingParty

  @type t :: %__MODULE__{
    client_id: String.t(),
    relying_party: RelyingParty.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "clients_relying_parties" do
    field(:client_id, :binary_id)

    belongs_to(:relying_party, RelyingParty)

    timestamps()
  end

  @doc false
  def changeset(client_relying_party, attrs) do
    client_relying_party
    |> cast(attrs, [:client_id, :relying_party_id])
    |> validate_required([:client_id, :relying_party_id])
    |> validate_format(
      :relying_party_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> validate_format(
      :client_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> foreign_key_constraint(:relying_party_id)
  end
end
