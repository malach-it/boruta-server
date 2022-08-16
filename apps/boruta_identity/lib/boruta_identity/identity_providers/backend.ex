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
    "argon2" => Argon2,
    "bcrypt" => Bcrypt,
    "pbkdf2" => Pbkdf2
  }

  @password_hashing_opts_schema %{
    "argon2" => %{
      "type" => "object",
      "properties" => %{
        "salt_len" => %{"type" => "number"},
        "t_cost" => %{"type" => "number"},
        "m_cost" => %{"type" => "number"},
        "parallelism" => %{"type" => "number"},
        "format" => %{"type" => "string", "pattern" => "^(encoded|raw_hash|report)$"},
        "hashlen" => %{"type" => "number"},
        "argon2_type" => %{"type" => "number", "minimum" => 0, "maximum" => 2}
      }
    }
  }

  @spec backend_types() :: list(atom)
  def backend_types, do: @backend_types

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "backends" do
    field(:type, :string)
    field(:is_default, :boolean, default: false)
    field(:name, :string)
    field(:password_hashing_alg, :string, default: "argon2")
    field(:password_hashing_opts, :map, default: %{})

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
  def password_hashing_opts(%__MODULE__{password_hashing_opts: password_hashing_opts}) do
    Enum.map(password_hashing_opts, fn
      {key, value} when is_binary(value) -> {String.to_atom(key), String.to_atom(value)}
      {key, value} -> {String.to_atom(key), value}
    end)
    |> Enum.into([])
  end

  @doc false
  def changeset(backend, attrs) do
    backend
    |> cast(attrs, [:type, :name, :is_default, :password_hashing_alg, :password_hashing_opts])
    |> validate_required([:name, :password_hashing_alg])
    |> validate_inclusion(:type, Enum.map(@backend_types, &Atom.to_string/1))
    |> validate_inclusion(:password_hashing_alg, Map.keys(@password_hashing_modules))
    |> foreign_key_constraint(:identity_provider, name: :identity_providers_backend_id_fkey)
    |> set_default()
    |> validate_password_hashing_opts()
  end

  defp set_default(%Ecto.Changeset{changes: %{is_default: false}} = changeset) do
    Ecto.Changeset.add_error(
      changeset,
      :is_default,
      "There must be at least one default backend."
    )
  end

  defp set_default(%Ecto.Changeset{changes: %{is_default: _is_default}} = changeset) do
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

  defp set_default(changeset), do: changeset

  defp validate_password_hashing_opts(changeset) do
    alg = fetch_field!(changeset, :password_hashing_alg)
    opts = fetch_field!(changeset, :password_hashing_opts)

    case ExJsonSchema.Validator.validate(@password_hashing_opts_schema[alg], opts) do
      :ok ->
        changeset

      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {message, path}, changeset ->
          add_error(changeset, :password_hashing_opts, "#{message} at #{path}")
        end)
    end
  end
end
