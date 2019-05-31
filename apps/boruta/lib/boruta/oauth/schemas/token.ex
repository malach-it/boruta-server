defmodule Boruta.Oauth.Token do
  use Ecto.Schema

  import Ecto.Changeset
  import Boruta.Config, only: [access_token_expires_in: 0, authorization_code_expires_in: 0]

  alias Boruta.Oauth.Client
  alias Boruta.Coherence.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tokens" do
    field(:type, :string)
    field(:value, :string)
    field(:expires_at, :integer)

    belongs_to(:client, Client)
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [])
    |> validate_required([])
  end

  def resource_owner_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :user_id])
    |> validate_required([:client_id, :user_id])
    |> put_change(:type, "access_token")
    # TODO better token randomization
    |> put_change(:value, :crypto.strong_rand_bytes(32) |> Base.encode16())
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  def machine_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id])
    |> validate_required([:client_id])
    |> put_change(:type, "access_token")
    # TODO better token randomization
    |> put_change(:value, :crypto.strong_rand_bytes(32) |> Base.encode16())
    |> put_change(:expires_at, :os.system_time(:seconds) + access_token_expires_in())
  end

  def authorization_code_changeset(token, attrs) do
    token
    |> cast(attrs, [:client_id, :user_id])
    |> validate_required([:client_id, :user_id])
    |> put_change(:type, "code")
    # TODO better token randomization
    |> put_change(:value, :crypto.strong_rand_bytes(16) |> Base.encode16())
    |> put_change(:expires_at, :os.system_time(:seconds) + authorization_code_expires_in())
  end
end
