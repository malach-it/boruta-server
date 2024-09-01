defmodule BorutaIdentity.Accounts.Role do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.RoleScope
  alias BorutaIdentity.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "roles" do
    field :name, :string
    field :scopes, {:array, :map}, virtual: true

    has_many :role_scopes, RoleScope, on_replace: :delete
    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> Repo.preload(:role_scopes)
    |> cast(attrs, [:id, :name])
    |> unique_constraint(:id, name: :roles_pkey)
    |> put_assoc(
      :role_scopes,
      (attrs[:scopes] || attrs["scopes"] || [])
      |> Enum.uniq()
      |> Enum.map(fn
        %{id: id} -> %RoleScope{scope_id: id}
        %{"id" => id} -> %RoleScope{scope_id: id}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
    )
    |> validate_required([:name])
  end
end
