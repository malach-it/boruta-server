defmodule BorutaIdentity.Accounts.UserAuthorizedScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.User

  @type t :: %__MODULE__{
          user_id: String.t(),
          name: String.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scopes_users" do
    field :name, :string
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> foreign_key_constraint(:user_id)
  end
end
