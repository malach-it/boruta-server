defmodule Boruta.Token do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Boruta.Config, only: [
    access_token_expires_in: 0,
    authorization_code_expires_in: 0,
    resource_owner_schema: 0,
    token_generator: 0
  ]

  alias Boruta.Client

  @type t :: %__MODULE__{
    type:  String.t(),
    value: String.t(),
    state: String.t(),
    scope: String.t(),
    redirect_uri: String.t(),
    expires_at: integer(),
    client: Client.t(),
    resource_owner: struct()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts type: :utc_datetime
  schema "tokens" do
    field(:type, :string)
    field(:value, :string)
    field(:refresh_token, :string)
    field(:state, :string)
    field(:scope, :string)
    field(:redirect_uri, :string)
    field(:expires_at, :integer)

    belongs_to(:client, Client)
    belongs_to(:resource_owner, resource_owner_schema())

    timestamps()
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :redirect_uri, :resource_owner_id, :state, :scope])
    |> validate_required([:client_id])
    |> put_change(:type, "access_token")
    |> put_value()
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  @doc false
  def changeset_with_refresh_token(token, attrs) do
    token
    |> cast(attrs, [:client_id, :redirect_uri, :resource_owner_id, :state, :scope])
    |> validate_required([:client_id])
    |> put_change(:type, "access_token")
    |> put_value()
    |> put_refresh_token()
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  @doc false
  def code_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :resource_owner_id, :redirect_uri, :state, :scope])
    |> validate_required([:client_id, :resource_owner_id, :redirect_uri])
    |> put_change(:type, "code")
    |> put_value()
    |> put_change(:expires_at, :os.system_time(:seconds) + authorization_code_expires_in())
  end

  defp put_value(%Ecto.Changeset{data: data, changes: changes} = changeset) do
    put_change(changeset, :value, token_generator().generate(:access_token, struct(data, changes)))
  end

  defp put_refresh_token(%Ecto.Changeset{data: data, changes: changes} = changeset) do
    put_change(changeset, :refresh_token, token_generator().generate(:refresh_token, struct(data, changes)))
  end
end
