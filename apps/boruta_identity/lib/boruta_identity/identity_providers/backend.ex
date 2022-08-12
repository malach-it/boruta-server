defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "backends" do
    field :password_hashing_alg, :string
    field :password_hashing_salt, :string
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(backend, attrs) do
    backend
    |> cast(attrs, [:type, :password_hashing_alg, :password_hashing_salt])
    |> validate_required([:type, :password_hashing_alg, :password_hashing_salt])
  end
end
