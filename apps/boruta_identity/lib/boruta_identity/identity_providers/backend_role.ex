defmodule BorutaIdentity.IdentityProviders.BackendRole do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.IdentityProviders.Backend

  @type t :: %__MODULE__{
    id: String.t(),
    backend_id: String.t(),
    role_id: String.t()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "backends_roles" do
    belongs_to :role, Role
    belongs_to :backend, Backend

    timestamps()
  end

  @doc false
  def changeset(role_scope, attrs) do
    role_scope
    |> cast(attrs, [:role_id, :backend_id])
    |> validate_required([:role_id, :backend_id])
    |> unique_constraint([:role_id, :backend_id])
  end
end
