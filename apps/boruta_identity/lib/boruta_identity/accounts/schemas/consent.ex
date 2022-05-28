defmodule BorutaIdentity.Accounts.Consent do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Internal.User

  @type t :: %__MODULE__{
          id: String.t(),
          client_id: String.t(),
          scopes: list(String.t()),
          user: Ecto.Association.NotLoaded.t() | User.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "consents" do
    field(:client_id, :string)
    field(:scopes, {:array, :string}, default: [])

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(consent, attrs) do
    consent
    |> cast(attrs, [:client_id, :scopes])
    |> validate_required([:client_id])
  end
end
