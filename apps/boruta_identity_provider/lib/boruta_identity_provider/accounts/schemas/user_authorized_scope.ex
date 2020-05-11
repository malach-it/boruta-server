defmodule BorutaIdentityProvider.Accounts.UserAuthorizedScope do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentityProvider.Accounts.User

  @type t :: %__MODULE__{
          user_id: String.t(),
          scope_id: String.t()
        }

  @primary_key false
  @foreign_key_type :binary_id
  schema "scopes_users" do
    field :scope_id, :binary_id
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:user_id, :scope_id])
    |> validate_required([:user_id, :scope_id])
  end
end
