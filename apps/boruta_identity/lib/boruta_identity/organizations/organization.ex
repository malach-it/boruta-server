defmodule BorutaIdentity.Organizations.Organization do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    label: String.t() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "organizations" do
    field(:name, :string)
    field(:label, :string)

    timestamps()
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :label])
    |> validate_required([:name])
  end
end
