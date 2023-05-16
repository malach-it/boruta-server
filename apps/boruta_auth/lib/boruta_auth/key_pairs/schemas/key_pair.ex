defmodule BorutaAuth.KeyPairs.KeyPair do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaAuth.Repo

  @type t :: %__MODULE__{
          id: String.t(),
          public_key: String.t(),
          private_key: String.t(),
          is_default: boolean() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "key_pairs" do
    field(:public_key, :string)
    field(:private_key, :string)
    field(:is_default, :boolean)

    timestamps()
  end

  @spec default!() :: t()
  def default! do
    case Repo.get_by(__MODULE__, is_default: true) do
      nil ->
        {:ok, key_pair} =
          changeset(%__MODULE__{}, %{is_default: true})
          |> Repo.insert()

        key_pair

      key_pair ->
        key_pair
    end
  end

  @doc false
  def changeset(key_pair, attrs) do
    key_pair
    |> cast(attrs, [:is_default])
    |> generate_key_pair()
    |> validate_required([:public_key, :private_key])
    |> set_default()
  end

  def delete_changeset(key_pair) do
    change(key_pair)
    |> check_default()
  end

  def rotate_changeset(key_pair) do
    change(key_pair)
    |> generate_key_pair()
  end

  defp set_default(%Ecto.Changeset{changes: %{is_default: true}} = changeset) do
    # TODO use a transaction to change default key_pair
    case change(default!(), %{is_default: false}) |> Repo.update() do
      {:ok, _key_pair} ->
        changeset

      {:error, changeset} ->
        add_error(
          changeset,
          :is_default,
          "Cannot remove value from the existing default key_pair."
        )
    end
  rescue
    Ecto.NoResultsError -> changeset
  end

  defp set_default(changeset), do: changeset

  defp generate_key_pair(changeset) do
    case get_field(changeset, :private_key) do
      nil ->
        private_key = JOSE.JWK.generate_key({:rsa, 1024, 65_537})
        public_key = JOSE.JWK.to_public(private_key)

        {_type, public_pem} = JOSE.JWK.to_pem(public_key)
        {_type, private_pem} = JOSE.JWK.to_pem(private_key)

        changeset
        |> put_change(:public_key, public_pem)
        |> put_change(:private_key, private_pem)

      _private_key ->
        changeset
    end
  end

  defp check_default(changeset) do
    case get_field(changeset, :is_default) do
      true ->
        add_error(
          changeset,
          :is_default,
          "Cannot delete a default key pair."
        )
      _ -> changeset
    end
  end
end
