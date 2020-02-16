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
  import Boruta.Config, only: [repo: 0]

  @type t :: [
    email: String.t()
  ]
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:email, :string)

    pow_user_fields()

    many_to_many :authorized_scopes, Scope, join_through: "scopes_users", on_replace: :delete

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
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [])
    |> put_assoc(:authorized_scopes, parse_authorized_scopes(attrs))
  end

  defp parse_authorized_scopes(attrs) do
    authorized_scope_ids = Enum.map(
      attrs["authorized_scopes"] || [],
      fn (scope_attrs) ->
        case apply_action(Scope.assoc_changeset(%Scope{}, scope_attrs), :replace) do
          {:ok, %{id: id}} -> id
          _ -> nil
        end
      end
    )
    authorized_scope_ids = authorized_scope_ids
                           |> Enum.reject(&is_nil/1)

    repo().all(
      from s in Scope,
      where: s.id in ^authorized_scope_ids
    )
  end
end
