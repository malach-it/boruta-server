defmodule BorutaGateway.Upstreams.Upstream do
  @moduledoc false

  @required_scopes_schema %{
    "type" => "object",
    "patternProperties" => %{
      "(GET|POST|PUT|HEAD|OPTIONS|PATCH|DELETE|\\*)" => %{
        "type" => "array",
        "items" => %{
          "type" => "string",
          "pattern" => ".+"
        },
        "minItems" => 1
      }
    },
    "additionalProperties" => false
  }

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaGateway.Upstreams.ClientSupervisor

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

    field(:http_client, :any, virtual: true)

    timestamps()
  end

  def with_http_client(%__MODULE__{http_client: nil} = upstream) do
    # TODO manage failure
    {:ok, http_client} = ClientSupervisor.client_for_upstream(upstream)

    %{upstream|http_client: http_client}
  end

  def with_http_client(%__MODULE__{http_client: http_client} = upstream) when is_pid(http_client) do
    ClientSupervisor.kill(http_client)
    # TODO manage failure
    {:ok, http_client} = Enum.reduce_while(1..100, http_client, fn _i, http_client ->
      :timer.sleep(10)
      case Process.alive?(http_client) do
        true ->
          {:cont, http_client}
        false ->
          {:halt, ClientSupervisor.client_for_upstream(upstream)}
      end
    end)

    %{upstream|http_client: http_client}
  end

  @doc false
  def changeset(upstream, attrs) do
    upstream
    |> cast(attrs, [:scheme, :host, :port, :uris, :strip_uri, :authorize, :required_scopes])
    |> validate_required([:scheme, :host, :port])
    |> validate_inclusion(:scheme, ["http", "https"])
    |> validate_uris()
    |> validate_required_scopes_format()
  end

  defp validate_uris(
         %Ecto.Changeset{
           changes: %{uris: uris}
         } = changeset
       ) do
    case Enum.any?(uris, fn uri -> is_nil(uri) || uri == "" end) do
      true -> add_error(changeset, :uris, "may not be blank")
      false -> changeset
    end
  end

  defp validate_uris(changeset), do: changeset

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
