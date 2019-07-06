defmodule Boruta.Oauth.Client do
  @moduledoc """
  OAuth client schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
    secret: String.t(),
    authorize_scope: boolean(),
    authorized_scopes: list(String.t()),
    redirect_uri: String.t()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field(:secret, :string)
    field(:authorize_scope, :boolean, default: false)
    field(:authorized_scopes, {:array, :string}, default: [])
    field(:redirect_uri, :string)

    timestamps()
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:redirect_uri])
  end
end
