defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          type: String.t(),
          name: String.t()
        }

  @backend_types [
    BorutaIdentity.Accounts.Internal
  ]

  @password_hashing_modules %{
    "argon2" => Argon2
  }

  @spec backend_types() :: list(atom)
  def backend_types, do: @backend_types

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "backends" do
    field(:type, :string)
    field(:name, :string)
    field(:password_hashing_alg, :string, default: "argon2")
    field(:password_hashing_salt, :string, default: "")

    timestamps()
  end

  @spec implementation(t()) :: atom()
  def implementation(%__MODULE__{type: type}) do
    String.to_atom(type)
  end

  @spec password_hashing_module(t()) :: atom()
  def password_hashing_module(%__MODULE__{password_hashing_alg: password_hashing_alg}) do
    @password_hashing_modules[password_hashing_alg]
  end

  @spec password_hashing_opts(t()) :: Keyword.t()
  def password_hashing_opts(_backend) do
    []
  end

  @doc false
  def changeset(backend, attrs) do
    backend
    |> cast(attrs, [:type, :name])
    |> validate_required([:name])
    |> validate_inclusion(:type, Enum.map(@backend_types, &Atom.to_string/1))
    |> validate_inclusion(:password_hashing_alg, Map.keys(@password_hashing_modules))
  end
end
