defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Repo

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
    field(:is_default, :boolean, default: false)
    field(:name, :string)
    field(:password_hashing_alg, :string, default: "argon2")
    field(:password_hashing_salt, :string, default: "")

    timestamps()
  end

  @spec default!() :: t()
  def default! do
    Repo.get_by!(__MODULE__, is_default: true)
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
    |> cast(attrs, [:type, :name, :is_default])
    |> validate_required([:name])
    |> validate_inclusion(:type, Enum.map(@backend_types, &Atom.to_string/1))
    |> validate_inclusion(:password_hashing_alg, Map.keys(@password_hashing_modules))
    |> set_default()
  end

  def set_default(
        %Ecto.Changeset{changes: %{is_default: false}} =
          changeset
      ) do
    Ecto.Changeset.add_error(
      changeset,
      :is_default,
      "There must be at least one default backend."
    )
  end

  def set_default(%Ecto.Changeset{changes: %{is_default: _is_default}} = changeset) do
    case Ecto.Changeset.change(default!(), %{is_default: false}) |> Repo.update() do
      {:ok, _backend} ->
        changeset

      {:error, changeset} ->
        Ecto.Changeset.add_error(
          changeset,
          :is_default,
          "Cannot remove value from the existing default backend."
        )
    end
  rescue
    Ecto.NoResultsError -> changeset
  end

  def set_default(changeset), do: changeset
end
