defmodule BorutaAuth.ClientBlsKeyPair do
  @moduledoc """
  Persisted one-to-one BLS12-381 key material for an OAuth client.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaAuth.BlsKeyPair
  alias BorutaAuth.Repo

  @derive {Inspect, except: [:private_key]}
  @primary_key {:client_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  @timestamps_opts type: :utc_datetime
  @type t :: %__MODULE__{
          client_id: Ecto.UUID.t(),
          private_key: binary(),
          public_key: binary(),
          did_key: String.t()
        }

  schema "oauth_clients_bls_key_pairs" do
    field(:private_key, :binary, redact: true)
    field(:public_key, :binary)
    field(:did_key, :string)

    timestamps()
  end

  @spec get(Ecto.UUID.t()) :: __MODULE__.t() | nil
  def get(client_id), do: Repo.get(__MODULE__, client_id)

  @spec get_or_create(Ecto.UUID.t()) ::
          {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create(client_id) do
    case get(client_id) do
      %__MODULE__{} = key_pair ->
        {:ok, key_pair}

      nil ->
        insert(client_id)
    end
  end

  defp insert(client_id) do
    key_pair = BlsKeyPair.generate()

    %__MODULE__{}
    |> cast(
      %{
        client_id: client_id,
        private_key: key_pair.private_key,
        public_key: key_pair.public_key,
        did_key: key_pair.did_key
      },
      [:client_id, :private_key, :public_key, :did_key]
    )
    |> validate_required([:client_id, :private_key, :public_key, :did_key])
    |> unique_constraint(:client_id, name: :oauth_clients_bls_key_pairs_pkey)
    |> unique_constraint(:did_key)
    |> Repo.insert(log: false)
    |> case do
      {:error, %Ecto.Changeset{errors: [client_id: _error]}} ->
        {:ok, Repo.get!(__MODULE__, client_id)}

      result ->
        result
    end
  end
end
