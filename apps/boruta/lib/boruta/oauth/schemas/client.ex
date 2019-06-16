defmodule Boruta.Oauth.Client do
  @moduledoc """
  OAuth client schema
  """

  use Ecto.Schema

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
    field(:authorize_scope, :boolean)
    field(:authorized_scopes, {:array, :string})
    field(:redirect_uri, :string)

    timestamps()
  end
end
