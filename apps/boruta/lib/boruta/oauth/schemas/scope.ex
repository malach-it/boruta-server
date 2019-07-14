defmodule Boruta.Oauth.Scope do
  # TODO move in Boruta.Oauth
  @moduledoc """
  TODO Scope documentation
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scopes" do
    field :name, :string
    field :public, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:name, :public])
    |> validate_required([:name])
    |> validate_not_nil(:public)
    |> validate_no_whitespace(:name)
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
