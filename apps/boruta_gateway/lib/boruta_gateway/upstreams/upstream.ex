defmodule BorutaGateway.Upstreams.Upstream do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    scheme: String.t(),
    host: String.t(),
    port: integer(),
    uris: list(String.t()),
    required_scopes: list(String.t()),
    strip_uri: boolean(),
    authorize: boolean(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "upstreams" do
    field(:scheme, :string)
    field(:host, :string)
    field(:port, :integer)
    field(:uris, {:array, :string}, default: [])
    field(:required_scopes, :map, default: %{})
    field(:strip_uri, :boolean, default: false)
    field(:authorize, :boolean, default: false)

    timestamps()
  end

  @doc false
  def changeset(upstream, attrs) do
    upstream
    |> cast(attrs, [:scheme, :host, :port, :uris, :strip_uri, :authorize, :required_scopes])
    |> validate_required([:scheme, :host, :port])
    |> validate_inclusion(:scheme, ["http", "https"])
  end
end
