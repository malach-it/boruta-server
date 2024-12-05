defmodule BorutaFederation.TrustChains do
  @moduledoc false

  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.FederationEntity

  @trust_chain_ttl 3600

  @spec generate_statement(entity :: FederationEntity.t()) ::
          {:ok, trust_chain :: list(String.t())} | {:error, reason :: String.t()}
  def generate_statement(entity, opts \\ []) do
    signer = Joken.Signer.create(entity.trust_chain_statement_alg, %{"pem" => entity.private_key})

    with {:ok, metadata} <- apply(String.to_atom(entity.type), :metadata, [entity]),
         {:ok, trust_marks} <- apply(String.to_atom(entity.type), :trust_marks, [entity]),
         {:ok, jwks} <- apply(String.to_atom(entity.type), :jwks, [entity]) do
      now = :os.system_time(:second)

      payload = %{
        "exp" => now + entity.trust_chain_statement_ttl,
        "iat" => now,
        "iss" => issuer(),
        "jwks" => jwks,
        "metadata" => metadata,
        "sub" => entity.id,
        "trust_marks" => trust_marks
      }

      with true <- opts[:include_trust_chain],
           {:ok, chain_statements} <-
             apply(String.to_atom(entity.type), :resolve_parents_chain, [entity]) do
        payload = Map.put(payload, "trust_chain", chain_statements)

        case Joken.encode_and_sign(payload, signer) do
          {:ok, statement, _payload} ->
            {:ok, statement}

          {:error, error} ->
            {:error, to_string(error)}
        end
      else
        {:error, error} ->
          {:error, error}

        _ ->
          case Joken.encode_and_sign(payload, signer) do
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
end
