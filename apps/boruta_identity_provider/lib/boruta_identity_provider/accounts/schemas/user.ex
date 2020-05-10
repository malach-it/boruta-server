defmodule Boruta.Accounts.User do
  @moduledoc false

  alias Boruta.Accounts.HashSalt
  alias Boruta.Ecto.Scope

  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&HashSalt.hashpwsalt/1,
                            &HashSalt.checkpw/2}
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation, PowResetPassword]

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import BorutaIdentityProvider.Config, only: [repo: 0]

  @type t :: [
    email: String.t()
  ]
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:email, :string)

    pow_user_fields()

    timestamps()
  end

  @doc false
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(model, attrs \\ %{}) do
    model
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
  end

  @spec update_changeset!(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def update_changeset!(model, attrs \\ %{}) do
    model
    |> cast(attrs, [])
  end
end
