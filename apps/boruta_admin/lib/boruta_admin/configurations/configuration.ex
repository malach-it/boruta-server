defmodule BorutaAdmin.Configurations.Configuration do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          value: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "configurations" do
    field(:name, :string)
    field(:value, :string)

    timestamps()
  end

  @doc false
  def changeset(upstream, attrs) do
    upstream
    |> cast(attrs, [
      :name,
      :value
    ])
    |> validate_required([:name, :value])
    |> unique_constraint(:name)
  end
end
