defmodule BorutaFederation.TrustChains do
  @moduledoc false

  alias BorutaFederation.FederationEntities.FederationEntity

  @spec generate_statement(entity :: FederationEntity.t()) ::
          {:ok, trust_chain :: list(String.t())} | {:error, reason :: String.t()}
  def generate_statement(entity) do
    signer = Joken.Signer.create(entity.trust_chain_statement_alg, %{"pem" => entity.private_key})

    with {:ok, metadata} <- apply(String.to_atom(entity.type), :metadata, [entity]),
         {:ok, jwks} <- apply(String.to_atom(entity.type), :jwks, [entity]) do
      payload = %{
        "jwks" => jwks,
        "metadata" => metadata
      }

      case Joken.encode_and_sign(payload, signer) do
        {:ok, statement, _payload} ->
          {:ok, statement}
        {:error, error} ->
          {:error, to_string(error)}
      end
    end
  end

  @spec generate_trust_chain(entity :: FederationEntity.t()) ::
          {:ok, trust_chain :: list(String.t())} | {:error, reason :: String.t()}
  def generate_trust_chain(entity) do
    with {:ok, statement} <- generate_statement(entity),
         {:ok, chain_statements} <-
           apply(String.to_atom(entity.type), :resolve_parents_chain, [entity]) do
      {:ok, chain_statements ++ [statement]}
    end
  end
end
