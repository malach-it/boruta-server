defmodule BorutaGateway.Upstreams.Upstream do
  @moduledoc false

  @required_scopes_schema %{
    "type" => "object",
    "patternProperties" => %{
      "(GET|POST|PUT|HEAD|OPTIONS|PATCH|DELETE)" => %{
        "type" => "array",
        "items" => %{
          "type" => "string"
        }
      }
    },
    "additionalProperties" => false
  }

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
    |> validate_required_scopes_format()
  end

  defp validate_required_scopes_format(
         %Ecto.Changeset{
           changes: %{required_scopes: required_scopes}
         } = changeset
       ) do
    case ExJsonSchema.Validator.validate(@required_scopes_schema, required_scopes) do
      :ok ->
        changeset

      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {message, path}, changeset ->
          add_error(changeset, :required_scopes, "#{message} at #{path}")
        end)
    end
  end

  defp validate_required_scopes_format(changeset), do: changeset
end
