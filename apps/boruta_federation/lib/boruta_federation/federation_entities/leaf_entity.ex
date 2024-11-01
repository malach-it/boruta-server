defmodule BorutaFederation.FederationEntities.LeafEntity do
  @moduledoc false

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

  @spec resolve_parents_chain(entity :: FederationEntity.t()) :: {:ok, chain :: list(String.t())}
  def resolve_parents_chain(_entity), do: {:ok, []}
end
