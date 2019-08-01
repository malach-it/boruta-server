defmodule Boruta.Oauth.Scope do
  @moduledoc """
  Schema defining an independent OAuth scope
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    name: String.t(),
    public: boolean()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scopes" do
    field :name, :string
    field :public, :boolean, default: false

    timestamps()
  end

  @doc """
  Splits an OAuth scope string into individual scopes as string
  ## Examples
      iex> scope("a:scope another:scope")
      ["a:scope", "another:scope"]
  """
  @spec split(oauth_scope :: String.t() | nil) :: list(String.t())
  def split(nil), do: []
  def split(scope) do
    Enum.filter(
      String.split(scope, " "),
      fn (scope) -> scope != "" end # remove empty strings
    )
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:id, :name, :public])
    |> unique_constraint(:id)
    |> unique_constraint(:name)
    |> validate_required([:name])
    |> validate_not_nil(:public)
    |> validate_no_whitespace(:name)
  end

  @doc false
  def assoc_changeset(scope, attrs) do
    scope
    |> cast(attrs, [:id])
    |> validate_required([:id])
  end

  defp validate_not_nil(changeset, field) do
    if get_field(changeset, field) == nil do
      add_error(changeset, field, "must not be null")
    else
      changeset
    end
  end

  defp validate_no_whitespace(changeset, field) do
    value = get_field(changeset, field)
    if value && String.match?(value, ~r/\s/) do
      add_error(changeset, field, "must not contain whitespace")
    else
      changeset
    end
  end
end
