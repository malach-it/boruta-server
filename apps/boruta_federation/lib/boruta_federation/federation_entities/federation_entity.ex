defmodule BorutaFederation.FederationEntities.FederationEntity do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaFederation.FederationEntities.ClientFederationEntity
  alias BorutaFederation.FederationEntities.Entity
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  @type t :: %__MODULE__{
    organization_name: String.t(),
    type: String.t(),
    trust_chain_statement_alg: String.t(),
    trust_chain_statement_ttl: integer(),
    trust_mark_logo_uri: String.t() | nil,
    authorities: list(String.t()),
    default: boolean(),
    key_pair_type: map(),
    public_key: String.t(),
    private_key: String.t(),
    max_depth: integer(),
    excluded: list(String.t()),
    permitted: list(String.t()),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @key_pair_type_schema %{
    "type" => "object",
    "properties" => %{
      "type" => %{"type" => "string", "pattern" => "^ec|rsa"},
      "modulus_size" => %{"type" => "string"},
      "exponent_size" => %{"type" => "string"},
      "curve" => %{"type" => "string", "pattern" => "^P-256|P-384|P-512"}
    },
    "required" => ["type"]
  }

  @types [
    Atom.to_string(Entity)
  ]

  @trust_chain_statement_algs [
    "RS256",
    "RS384",
    "RS512",
    "ES256",
    "ES384",
    "ES512",
  ]

  @key_pair_type_jwt_algs %{
    "ec" => [
      "ES256",
      "ES384",
      "ES512"
    ],
    "rsa" => [
      "RS256",
      "RS384",
      "RS512"
    ]
  }

  @authority_schema %{
    "type" => "object",
    "properties" => %{
      "issuer" => %{"type" => "string"},
      "sub" => %{"type" => "string"}
    },
    "required" => ["issuer", "sub"]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "federation_entities" do
    field(:organization_name, :string)
    field(:type, :string, default: "Elixir.BorutaFederation.FederationEntities.Entity")
    field(:public_key, :string)
    field(:private_key, :string)
    field(:trust_chain_statement_alg, :string)
    field(:trust_chain_statement_ttl, :integer, default: 3600 * 24)
    field(:authorities, {:array, :map}, default: [])
    field(:default, :boolean, default: false)
    field(:trust_mark_logo_uri, :string)
    field(:key_pair_type, :map,
      default: %{
        "type" => "rsa",
        "modulus_size" => "1024",
        "exponent_size" => "65537"
      }
    )
    field(:max_depth, :integer)
    field(:permitted, {:array, :string})
    field(:excluded, {:array, :string})

    has_many(:client_federation_entities, ClientFederationEntity)

    timestamps()
  end

  def create_changeset(entity, attrs) do
    entity
    |> cast(attrs, [
      :organization_name,
      :type,
      :key_pair_type,
      :trust_chain_statement_alg,
      :trust_chain_statement_ttl,
      :trust_mark_logo_uri,
      :authorities,
      :default,
      :max_depth,
      :permitted,
      :excluded
    ])
    |> validate_key_pair_type()
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:trust_chain_statement_alg, @trust_chain_statement_algs)
    |> generate_key_pair()
    |> validate_authorities()
    |> validate_required([:organization_name, :type, :public_key, :private_key])
  end

  defp validate_key_pair_type(changeset) do
    key_pair_type = get_field(changeset, :key_pair_type)

    case ExJsonSchema.Validator.validate(
           @key_pair_type_schema,
           key_pair_type,
           error_formatter: BorutaFormatter
         ) do
      :ok ->
        changeset
        |> validate_inclusion(
          :trust_chain_statement_alg,
          @key_pair_type_jwt_algs[key_pair_type["type"]]
        )

      {:error, errors} ->
        add_error(changeset, :key_pair_type, "validation failed: #{Enum.join(errors, " ")}")
    end
  end

  defp generate_key_pair(changeset) do
    private_key =
      case get_field(changeset, :key_pair_type) do
        %{"type" => "rsa", "modulus_size" => modulus_size, "exponent_size" => exponent_size} ->
          JOSE.JWK.generate_key(
            {:rsa, String.to_integer(modulus_size), String.to_integer(exponent_size)}
          )

        %{"type" => "ec", "curve" => curve} ->
          JOSE.JWK.generate_key({:ec, curve})

        _ ->
          nil
      end

    case private_key do
      nil ->
        add_error(changeset, :private_key, "private_key_type is invalid")

      private_key ->
        public_key = JOSE.JWK.to_public(private_key)

        {_type, public_pem} = JOSE.JWK.to_pem(public_key)
        {_type, private_pem} = JOSE.JWK.to_pem(private_key)

        changeset
        |> put_change(:public_key, public_pem)
        |> put_change(:private_key, private_pem)
    end
  end

  defp validate_authorities(changeset) do
    Enum.reduce(get_field(changeset, :authorities), changeset, fn authority, changeset ->
      case ExJsonSchema.Validator.validate(
        @authority_schema,
        authority,
        error_formatter: BorutaFormatter
      ) do
        :ok ->
          case validate_url(authority["issuer"]) do
            nil ->
              changeset
            error ->
              add_error(changeset, :authorities, error)
          end

        {:error, errors} ->
          add_error(changeset, :authorities, "validation failed: #{Enum.join(errors, " ")}")
      end
    end)
  end

  defp validate_url(nil), do: "empty values are not allowed"

  defp validate_url("" <> url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, fragment: fragment}
      when not is_nil(scheme) and not is_nil(host) and is_nil(fragment) ->
        nil

      _ ->
        "`#{url}` is invalid"
    end
  end
end
