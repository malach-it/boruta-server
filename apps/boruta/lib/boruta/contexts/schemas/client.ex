defmodule Boruta.Client do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [token_generator: 0, repo: 0]

  alias Boruta.Scope

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
    field(:redirect_uri, :string)

    many_to_many :authorized_scopes, Scope, join_through: "clients_scopes", on_replace: :delete

    timestamps()
  end

  @doc false
  def create_changeset(client, attrs) do
    client
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:redirect_uri, :authorize_scope])
    |> put_assoc(:authorized_scopes, parse_authorized_scopes(attrs))
    |> put_secret()
    |> validate_format(
      :redirect_uri,
      ~r{^(([a-z][a-z0-9\+\-\.]*):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}i
    ) # RFC 3986 URI format
  end

  @doc false
  def update_changeset(client, attrs) do
    client
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:redirect_uri, :authorize_scope])
    |> put_assoc(:authorized_scopes, parse_authorized_scopes(attrs))
    |> validate_format(
      :redirect_uri,
      ~r{^(([a-z][a-z0-9\+\-\.]*):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}i
    ) # RFC 3986 URI format
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

  defp put_secret(%Ecto.Changeset{data: data, changes: changes} = changeset) do
    put_change(changeset, :secret, token_generator().secret(struct(data, changes)))
  end
end
