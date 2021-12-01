defmodule BorutaIdentity.RelyingParties.ClientRelyingParty do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.RelyingParty

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "clients_relying_parties" do
    field :client_id, :binary_id

    belongs_to :relying_party, RelyingParty

    timestamps()
  end

  @doc false
  def changeset(client_relying_party, attrs) do
    client_relying_party
    |> cast(attrs, [])
    |> validate_required([])
  end
end
