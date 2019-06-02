defmodule Boruta.Oauth.Client do
  @moduledoc """
  TODO OAuth client
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field(:secret, :string)
    field(:authorize_scope, :boolean)
    field(:authorized_scopes, {:array, :string})
    field(:redirect_uri, :string)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [])
    |> validate_required([])
  end
end
