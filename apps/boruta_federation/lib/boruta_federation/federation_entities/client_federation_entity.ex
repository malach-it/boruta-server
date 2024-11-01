defmodule BorutaFederation.FederationEntities.ClientFederationEntity do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaFederation.FederationEntities.FederationEntity

  @type t :: %__MODULE__{
    client_id: String.t(),
    federation_entity: FederationEntity.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "clients_federation_entities" do
    field(:client_id, :binary_id)

    belongs_to(:federation_entity, FederationEntity)

    timestamps()
  end

  @doc false
  def changeset(client_identity_provider, attrs) do
    client_identity_provider
    |> cast(attrs, [:client_id, :federation_entity_id])
    |> validate_required([:client_id, :federation_entity_id])
    |> validate_format(
      :federation_entity_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> validate_format(
      :client_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> foreign_key_constraint(:federation_entity_id)
  end
end
