defmodule BorutaIdentity.Accounts.UserRole do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "roles_users" do
    belongs_to(:role, Role)
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:role_id, :user_id])
    |> validate_required([:role_id, :user_id])
    |> unique_constraint([:role_id, :user_id], name: "roles_users_role_id_user_id_index", error_key: :users, message: "must be unique")
  end
end
