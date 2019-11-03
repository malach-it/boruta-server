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
    redirect_uris: list(String.t())
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field(:secret, :string)
    field(:authorize_scope, :boolean, default: false)
    field(:redirect_uris, {:array, :string})

    many_to_many :authorized_scopes, Scope, join_through: "clients_scopes", on_replace: :delete

    timestamps()
  end

  @doc false
  def create_changeset(client, attrs) do
    client
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:redirect_uris, :authorize_scope])
    |> validate_redirect_uris
    |> put_assoc(:authorized_scopes, parse_authorized_scopes(attrs))
    |> put_secret()
  end

  @doc false
  def update_changeset(client, attrs) do
    client
    |> repo().preload(:authorized_scopes)
    |> cast(attrs, [:redirect_uris, :authorize_scope])
    |> validate_redirect_uris
    |> put_assoc(:authorized_scopes, parse_authorized_scopes(attrs))
  end

  defp validate_redirect_uris(changeset) do
    validate_change(changeset, :redirect_uris, fn (field, values) ->
      Enum.map(values, &validate_uri/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn (error) -> {field, error} end)
    end)
  end

  defp validate_uri(nil), do: "empty values are not allowed"
  defp validate_uri("" <> uri) do
    case URI.parse(uri) do
      %URI{scheme: scheme, host: host}
      when not is_nil(scheme) and not is_nil(host) -> nil
      _ -> "`#{uri}` is invalid"
    end
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
