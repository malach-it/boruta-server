defmodule BorutaIdentity.Accounts.User do
  @moduledoc false

  import BorutaIdentity.Config, only: [repo: 0]

  alias BorutaIdentity.Accounts.HashSalt
  alias BorutaIdentity.Accounts.UserAuthorizedScope

  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&HashSalt.hashpwsalt/1,
                            &HashSalt.checkpw/2}
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation, PowResetPassword]

  import Ecto.Changeset

  alias BorutaIdentity.Accounts.UserAuthorizedScope

  @type t :: [
    email: String.t()
  ]
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:email, :string)

    pow_user_fields()

    has_many(:authorized_scopes, UserAuthorizedScope, on_replace: :delete)

    timestamps()
  end

  @doc false
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
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:email])
    |> cast_assoc(:authorized_scopes, with: &UserAuthorizedScope.changeset/2)
  end
end
