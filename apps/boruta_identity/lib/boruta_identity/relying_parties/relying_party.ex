defmodule BorutaIdentity.RelyingParties.RelyingParty do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "relying_parties" do
    field :name, :string
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(relying_party, attrs) do
    relying_party
    |> cast(attrs, [:name, :type])
    |> validate_required([:name, :type])
  end
end
