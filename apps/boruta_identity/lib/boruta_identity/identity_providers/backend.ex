defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "backends" do
    field :type, :string
    field :name, :string
    field :password_hashing_alg, :string, default: "argon2"
    field :password_hashing_salt, :string, default: ""

    timestamps()
  end

  @doc false
  def changeset(backend, attrs) do
    backend
    |> cast(attrs, [:type, :name])
    |> validate_required([:type, :name])
  end
end
