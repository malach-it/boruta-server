defmodule BorutaIdentity.Accounts.RoleScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
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
    |> unique_constraint([:role_id, :scope_id], name: "roles_scopes_role_id_scope_id_index", error_key: :scopes, message: "must be unique")
  end
end
