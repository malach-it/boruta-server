defmodule BorutaIdentity.Organizations.Organization do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "organizations" do
    field(:name, :string)

    timestamps()
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
