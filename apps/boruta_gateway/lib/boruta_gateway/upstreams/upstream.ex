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

  import Boruta.Config,
    only: [
      token_generator: 0
    ]

  @type t :: %__MODULE__{
          node_name: String.t(),
          scheme: String.t(),
          host: String.t(),
          port: integer(),
          uris: list(String.t()),
          required_scopes: map(),
          strip_uri: boolean(),
          authorize: boolean(),
          keepalive: boolean(),
          error_content_type: String.t() | nil,
          forbidden_response: String.t() | nil,
          unauthorized_response: String.t() | nil,
          rate_limit_enabled: boolean(),
          rate_limit_count: integer(),
          rate_limit_time_unit: String.t(),
          rate_limit_penality: integer(),
          rate_limit_timeout: integer(),
          rate_limit_memory_length: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "upstreams" do
    field(:node_name, :string, default: "global")
    field(:scheme, :string)
    field(:host, :string)
    field(:port, :integer)
    field(:uris, {:array, :string}, default: [])
    field(:required_scopes, :map, default: %{})
    field(:strip_uri, :boolean, default: false)
    field(:authorize, :boolean, default: false)
    field(:keepalive, :boolean, default: false)
    field(:error_content_type, :string, default: "application/json")
    field(:forbidden_response, :string)
    field(:unauthorized_response, :string)
    field(:forwarded_token_signature_alg, :string)
    field(:forwarded_token_secret, :string)
    field(:forwarded_token_public_key, :string)
    field(:forwarded_token_private_key, :string)
    field(:rate_limit_enabled, :boolean, default: false)
    field(:rate_limit_count, :integer, default: 10)
    field(:rate_limit_time_unit, :string, default: "second")
    field(:rate_limit_penality, :integer, default: 500)
    field(:rate_limit_timeout, :integer, default: 5_000)
    field(:rate_limit_memory_length, :integer, default: 50)

    timestamps()
  end

  def required_scopes(%__MODULE__{required_scopes: required_scopes}, method) do
    default_scopes = Map.get(required_scopes, "*", [])
    Map.get(required_scopes, method, default_scopes)
  end

  @doc false
  def changeset(upstream, attrs) do
    upstream
    |> cast(attrs, [
      :node_name,
      :scheme,
      :host,
      :port,
      :uris,
      :strip_uri,
      :authorize,
      :required_scopes,
      :keepalive,
      :error_content_type,
      :forbidden_response,
      :unauthorized_response,
      :forwarded_token_signature_alg,
      :forwarded_token_secret,
      :rate_limit_enabled,
      :rate_limit_count,
      :rate_limit_time_unit,
      :rate_limit_penality,
      :rate_limit_timeout,
      :rate_limit_memory_length
    ])
    |> validate_required([:scheme, :host, :port])
    |> validate_inclusion(:scheme, ["http", "https"])
    |> validate_inclusion(:rate_limit_count, 1..100_000)
    |> validate_inclusion(:rate_limit_time_unit, ["millisecond", "second", "minute"])
    |> validate_inclusion(:rate_limit_penality, 0..600_000)
    |> validate_inclusion(:rate_limit_timeout, 0..600_000)
    |> validate_inclusion(:rate_limit_memory_length, 1..10_000)
    |> unique_constraint([:node_name, :host, :port, :uris])
    |> maybe_put_forwarded_token_secret()
    |> maybe_generate_key_pair()
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

  defp maybe_put_forwarded_token_secret(%Ecto.Changeset{data: data, changes: changes} = changeset) do
    signature_algorithm = get_field(changeset, :forwarded_token_signature_alg)

    if signature_algorithm && String.match?(signature_algorithm, ~r/HS/) do
      case fetch_field(changeset, :forwarded_token_secret) do
        {_, nil} ->
          put_change(
            changeset,
            :forwarded_token_secret,
            token_generator().secret(struct(data, changes))
          )

        {_, _secret} ->
          changeset

        :error ->
          put_change(
            changeset,
            :forwarded_token_secret,
            token_generator().secret(struct(data, changes))
          )
      end
    else
      changeset
    end
  end

  defp maybe_generate_key_pair(changeset) do
    signature_algorithm = get_field(changeset, :forwarded_token_signature_alg)

    if signature_algorithm && String.match?(signature_algorithm, ~r/RS/) do
      case fetch_field(changeset, :forwarded_token_private_key) do
        {_, "" <> _private_key} ->
          changeset

        _ ->
          private_key = JOSE.JWK.generate_key({:rsa, 2048, 65_537})
          public_key = JOSE.JWK.to_public(private_key)

          {_type, public_pem} = JOSE.JWK.to_pem(public_key)
          {_type, private_pem} = JOSE.JWK.to_pem(private_key)

          changeset
          |> put_change(:forwarded_token_public_key, public_pem)
          |> put_change(:forwarded_token_private_key, private_pem)
      end
    else
      changeset
    end
  end
end
