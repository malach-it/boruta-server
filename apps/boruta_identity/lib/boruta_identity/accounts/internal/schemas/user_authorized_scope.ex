defmodule BorutaIdentity.Accounts.UserAuthorizedScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.User

  @type t :: %__MODULE__{
          user: Ecto.Association.NotLoaded.t() | User.t(),
          name: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_authorized_scopes" do
    field(:name, :string)
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> unique_constraint([:name, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
