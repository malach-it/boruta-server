defmodule BorutaIdentity.IdentityProviders.ClientIdentityProvider do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @type t :: %__MODULE__{
    client_id: String.t(),
    identity_provider: IdentityProvider.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "clients_identity_providers" do
    field(:client_id, :binary_id)

    belongs_to(:identity_provider, IdentityProvider)

    timestamps()
  end

  @doc false
  def changeset(client_identity_provider, attrs) do
    client_identity_provider
    |> cast(attrs, [:client_id, :identity_provider_id])
    |> validate_required([:client_id, :identity_provider_id])
    |> validate_format(
      :identity_provider_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> validate_format(
      :client_id,
      ~r/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    )
    |> foreign_key_constraint(:identity_provider_id)
  end
end
