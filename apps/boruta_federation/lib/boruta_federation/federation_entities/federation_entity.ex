defmodule BorutaFederation.FederationEntities.FederationEntity do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaFederation.FederationEntities.ClientFederationEntity
  alias BorutaFederation.FederationEntities.LeafEntity
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  @type t :: %__MODULE__{
    organization_name: String.t(),
    type: String.t(),
    trust_chain_statement_alg: String.t(),
    trust_chain_statement_ttl: integer(),
    trust_mark_logo_uri: String.t() | nil,
    key_pair_type: map(),
    public_key: String.t(),
    private_key: String.t(),
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
    Atom.to_string(LeafEntity)
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

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "federation_entities" do
    field(:organization_name, :string)
    field(:type, :string, default: "Elixir.BorutaFederation.FederationEntities.LeafEntity")
    field(:public_key, :string)
    field(:private_key, :string)
    field(:trust_chain_statement_alg, :string)
    field(:trust_chain_statement_ttl, :integer, default: 3600 * 24)
    field(:trust_mark_logo_uri, :string)
    field(:key_pair_type, :map,
      default: %{
        "type" => "rsa",
        "modulus_size" => "1024",
        "exponent_size" => "65537"
      }
    )

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
      :trust_mark_logo_uri
    ])
    |> validate_key_pair_type()
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:trust_chain_statement_alg, @trust_chain_statement_algs)
    |> generate_key_pair()
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
end