defmodule BorutaFederation.TrustChains do
  @moduledoc false

  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.FederationEntity

  @spec generate_statement(entity :: FederationEntity.t()) ::
          {:ok, trust_chain :: list(String.t())} | {:error, reason :: String.t()}
  def generate_statement(entity, opts \\ []) do
    with {:ok, metadata} <- apply(String.to_atom(entity.type), :metadata, [entity]),
         {:ok, trust_marks} <- apply(String.to_atom(entity.type), :trust_marks, [entity]) do
      payload = %{
        "metadata" => metadata,
        "trust_marks" => trust_marks
      }

      with true <- opts[:include_trust_chain],
           {:ok, chain_statements} <-
             apply(String.to_atom(entity.type), :resolve_parents_chain, [entity]) do
        payload = Map.put(payload, "trust_chain", chain_statements)

        with {:ok, statement, _payload} <- sign(payload, entity) do
          {:ok, statement}
        end
      else
        {:error, error} ->
          {:error, error}

        _ ->
          case sign(payload, entity) do
            {:ok, statement, _payload} ->
              {:ok, statement}

            {:error, error} ->
              {:error, to_string(error)}
          end
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

  @spec sign(payload :: map(), entity :: FederationEntity.t()) :: {:ok, jwt :: String.t(), payload :: map()} | {:error, reason :: String.t()}
  def sign(payload, entity) do
    signer = Joken.Signer.create(entity.trust_chain_statement_alg, %{"pem" => entity.private_key})

    with {:ok, jwks} <- apply(String.to_atom(entity.type), :jwks, [entity]) do
      now = :os.system_time(:second)
      base = %{
        "exp" => now + entity.trust_chain_statement_ttl,
        "iat" => now,
        "iss" => issuer(),
        "jwks" => jwks,
        "sub" => issuer() <> "/federation/federation_entities/#{entity.id}",
      }
      payload = Map.merge(base, payload)

      case Joken.encode_and_sign(payload, signer) do
        {:ok, jwt, claims} ->
          {:ok, jwt, claims}
        {:error, error} ->
          {:error, to_string(error)}
      end
    end
  end
end
