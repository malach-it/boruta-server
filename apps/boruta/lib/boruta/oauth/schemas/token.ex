defmodule Boruta.Oauth.Token do
  @moduledoc """
  Oauth token Schema

  Persist Token into database, provide some utilities too.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Boruta.Config, only: [
    access_token_expires_in: 0,
    authorization_code_expires_in: 0,
    resource_owner_schema: 0
  ]

  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Token

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
    field(:state, :string)
    field(:scope, :string)
    field(:redirect_uri, :string)
    field(:expires_at, :integer)

    belongs_to(:client, Client)
    belongs_to(:resource_owner, resource_owner_schema())

    timestamps()
  end

  @doc """
  Determines if a token is expired

  ## Examples
      iex> expired?(%Boruta.Oauth.Token{expires_at: 1638316800}) # 1st january 2021
      :ok

      iex> expired?(%Boruta.Oauth.Token{expires_at: 0}) # 1st january 1970
      {:error, "Token expired."}
  """
  # TODO move this out of the schema
  @spec expired?(%Boruta.Oauth.Token{expires_at: integer()}) :: :ok | {:error, any()}
  def expired?(%Token{expires_at: expires_at}) do
    case :os.system_time(:seconds) < expires_at do
      true -> :ok
      false -> {:error, "Token expired."}
    end
  end

  @doc false
  def resource_owner_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :resource_owner_id, :state, :scope])
    |> validate_required([:client_id, :resource_owner_id])
    |> put_change(:type, "access_token")
    # TODO better token randomization
    |> put_change(:value, SecureRandom.uuid)
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  @doc false
  def machine_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :scope])
    |> validate_required([:client_id])
    |> put_change(:type, "access_token")
    # TODO better token randomization
    |> put_change(:value, SecureRandom.uuid)
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  @doc false
  def code_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :resource_owner_id, :redirect_uri, :state, :scope])
    |> validate_required([:client_id, :resource_owner_id, :redirect_uri])
    |> put_change(:type, "code")
    # TODO better token randomization
    |> put_change(:value, SecureRandom.uuid)
    |> put_change(:expires_at, :os.system_time(:seconds) + authorization_code_expires_in())
  end
end
