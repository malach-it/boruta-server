defmodule Boruta.Oauth.Client do
  @moduledoc """
  OAuth client schema
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Boruta.Config, only: [token_generator: 0]

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

  @doc false
  def create_changeset(client, attrs) do
    client
    |> cast(attrs, [:redirect_uri, :authorize_scope, :authorized_scopes])
    |> put_secret()
    |> validate_format(
      :redirect_uri,
      ~r{^(([a-z][a-z0-9\+\-\.]*):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}i
    ) # RFC 3986 URI format
  end

  @doc false
  def update_changeset(client, attrs) do
    client
    |> cast(attrs, [:redirect_uri, :authorize_scope, :authorized_scopes])
    |> validate_format(
      :redirect_uri,
      ~r{^(([a-z][a-z0-9\+\-\.]*):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}i
    ) # RFC 3986 URI format
  end

  defp put_secret(%Ecto.Changeset{data: data, changes: changes} = changeset) do
    put_change(changeset, :secret, token_generator().secret(struct(data, changes)))
  end
end
