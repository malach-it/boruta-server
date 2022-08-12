defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @backend_types [
    BorutaIdentity.Accounts.Internal
  ]

  @spec backend_types() :: list(atom)
  def backend_types, do: @backend_types

  @primary_key {:id, Ecto.UUID, autogenerate: true}
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
    |> validate_required([:name])
    |> validate_inclusion(:type, Enum.map(@backend_types, &Atom.to_string/1))
  end
end
