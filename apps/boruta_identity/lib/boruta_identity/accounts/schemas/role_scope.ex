defmodule BorutaIdentity.Accounts.RoleScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "roles_scopes" do
    field :role_id, Ecto.UUID
    field :scope_id, Ecto.UUID

    timestamps()
  end

  @doc false
  def changeset(role_scope, attrs) do
    role_scope
    |> cast(attrs, [:role_id, :scope_id])
    |> validate_required([:role_id, :scope_id])
  end
end
