defmodule BorutaIdentity.Organizations.OrganizationUser do
  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Organizations.Organization

  @type t :: %__MODULE__{
    user_id: String.t(),
    organization_id: String.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @foreign_key_type Ecto.UUID
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "organizations_users" do
    belongs_to :user, User
    belongs_to :organization, Organization

    timestamps()
  end

  @doc false
  def changeset(organization_user, attrs) do
    organization_user
    |> cast(attrs, [:organization_id, :user_id])
    |> validate_required([:organization_id, :user_id])
  end
end
