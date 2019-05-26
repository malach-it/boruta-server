defmodule Boruta.Oauth.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "clients" do
    field(:secret, :string)

    timestamps()
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [])
    |> validate_required([])
  end
end
