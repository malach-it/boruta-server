defmodule BorutaFederation.FederationEntities.LeafEntity do
  @moduledoc false

  alias BorutaFederation.FederationEntities.FederationEntity

  import Boruta.Config, only: [issuer: 0]

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
  end

  @spec metadata(entity :: FederationEntity.t()) :: {:ok, metadata :: map()}
  def metadata(entity) do
    {:ok, %{
      "openid_provider" => %{
        "issuer" => issuer(),
        "organization_name" => entity.organization_name
      }
    }}
  end

  @spec jwks(entity :: FederationEntity.t()) :: {:ok, jwks :: map()}
  def jwks(entity) do
    {:ok, [JOSE.JWK.from_pem(entity.public_key) |> JOSE.JWK.to_map() |> elem(1)]}
  end

  @spec trust_marks(entity :: FederationEntity.t()) :: {:ok, trust_mark :: list(String.t())}
  def trust_marks(entity) do
    signer = Joken.Signer.create(entity.trust_chain_statement_alg, %{"pem" => entity.private_key})

    payload = %{
      "iss" => issuer(),
      "sub" => issuer(),
      "id" => entity.id,
      "iat" => :os.system_time(:second),
      "logo_uri" => entity.trust_mark_logo_uri
    }

    case Joken.encode_and_sign(payload, signer) do
      {:ok, trust_mark, _payload} ->
        {:ok, [trust_mark]}
      {:error, error} ->
        {:error, to_string(error)}
    end
  end

  @spec resolve_parents_chain(entity :: FederationEntity.t()) :: {:ok, chain :: list(String.t())}
  def resolve_parents_chain(_entity), do: {:ok, []}
end
