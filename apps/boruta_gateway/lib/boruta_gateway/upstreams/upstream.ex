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

  alias BorutaGateway.Upstreams.ClientSupervisor

  @type t :: %__MODULE__{
          node_name: String.t(),
          scheme: String.t(),
          host: String.t(),
          port: integer(),
          uris: list(String.t()),
          required_scopes: list(String.t()),
          strip_uri: boolean(),
          authorize: boolean(),
          error_content_type: String.t() | nil,
          forbidden_response: String.t() | nil,
          unauthorized_response: String.t() | nil,
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
    field(:pool_size, :integer, default: 10)
    field(:pool_count, :integer, default: 1)
    field(:max_idle_time, :integer, default: 10)
    field(:error_content_type, :string)
    field(:forbidden_response, :string)
    field(:unauthorized_response, :string)
    field(:forwarded_token_signature_alg, :string)
    field(:forwarded_token_secret, :string)
    field(:forwarded_token_public_key, :string)
    field(:forwarded_token_private_key, :string)

    field(:http_client, :any, virtual: true)

    timestamps()
  end

  def with_http_client(%__MODULE__{http_client: nil} = upstream) do
    # TODO manage failure
    {:ok, http_client} = ClientSupervisor.client_for_upstream(upstream)

    %{upstream | http_client: http_client}
  end

  def with_http_client(%__MODULE__{http_client: http_client} = upstream)
      when is_pid(http_client) do
    ClientSupervisor.kill(http_client)
    # TODO manage failure
    {:ok, http_client} =
      Enum.reduce_while(1..100, http_client, fn _i, http_client ->
        :timer.sleep(10)

        case Process.alive?(http_client) do
          true ->
            {:cont, http_client}

          false ->
            {:halt, ClientSupervisor.client_for_upstream(upstream)}
        end
      end)

    %{upstream | http_client: http_client}
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
      :pool_size,
      :pool_count,
      :max_idle_time,
      :error_content_type,
      :forbidden_response,
      :unauthorized_response,
      :forwarded_token_signature_alg,
      :forwarded_token_secret
    ])
    |> validate_required([:scheme, :host, :port])
    |> validate_inclusion(:scheme, ["http", "https"])
    |> validate_inclusion(:pool_size, 1..100)
    |> validate_inclusion(:pool_count, 1..10)
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
          private_key = JOSE.JWK.generate_key({:rsa, 1024, 65_537})
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
