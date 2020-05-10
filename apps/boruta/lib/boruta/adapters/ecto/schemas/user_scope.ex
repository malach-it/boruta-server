defmodule Boruta.Ecto.UserAuthorizedScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Boruta.Ecto.Scope

  @type t :: %__MODULE__{
          resource_owner_id: String.t(),
          scope_id: String.t()
        }

  @primary_key false
  @foreign_key_type :binary_id
  schema "resource_owners_scopes" do
    field :resource_owner_id, :string

    belongs_to(:scope, Scope)

    timestamps()
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:resource_owner_id, :scope_id])
    |> validate_required([:resource_owner_id, :scope_id])
  end
end
