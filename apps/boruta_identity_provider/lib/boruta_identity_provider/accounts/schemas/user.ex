defmodule BorutaIdentityProvider.Accounts.User do
  @moduledoc false

  import BorutaIdentityProvider.Config, only: [repo: 0]

  alias BorutaIdentityProvider.Accounts.HashSalt
  alias BorutaIdentityProvider.Accounts.UserAuthorizedScope

  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&HashSalt.hashpwsalt/1,
                            &HashSalt.checkpw/2}
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation, PowResetPassword]

  import Ecto.Changeset

  alias BorutaIdentityProvider.Accounts.UserAuthorizedScope

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
    attrs = add_authorized_scopes_params(attrs, model)
    model
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:email])
    |> cast_assoc(:authorized_scopes)
  end

  defp add_authorized_scopes_params(%{"authorized_scopes" => authorized_scopes} = attrs, model) do
    authorized_scopes = Enum.map(
      authorized_scopes,
      fn (%{"id" => id}) -> %{user_id: model.id, scope_id: id} end
    )
    %{attrs|"authorized_scopes" => authorized_scopes}
  end
  defp add_authorized_scopes_params(attrs, _model), do: attrs
end
