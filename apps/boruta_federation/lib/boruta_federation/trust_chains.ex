defmodule BorutaFederation.TrustChains do
  @moduledoc false

  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.Entity
  alias BorutaFederation.FederationEntities.FederationEntity

  @spec generate_statement(entity :: FederationEntity.t()) ::
          {:ok, trust_chain :: list(String.t())} | {:error, reason :: String.t()}
  def generate_statement(entity, opts \\ []) do
    with {:ok, metadata} <- apply(String.to_atom(entity.type), :metadata, [entity]),
         {:ok, trust_marks} <- apply(String.to_atom(entity.type), :trust_marks, [entity]),
         {:ok, constraints} <- apply(String.to_atom(entity.type), :constraints, [entity]) do
      payload = %{
        "metadata" => metadata,
        "trust_marks" => trust_marks,
        "constraints" => constraints
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
           apply(String.to_atom(entity.type), :resolve_parents_chain, [entity]),
         {:ok, trust_chain} <- validate_trust_chain(chain_statements ++ [statement]) do
      {:ok, trust_chain}
    end
  end

  @spec sign(payload :: map(), entity :: FederationEntity.t()) ::
          {:ok, jwt :: String.t(), payload :: map()} | {:error, reason :: String.t()}
  def sign(payload, entity) do
    signer = Joken.Signer.create(entity.trust_chain_statement_alg, %{"pem" => entity.private_key})

    with {:ok, jwks} <- apply(String.to_atom(entity.type), :jwks, [entity]) do
      now = :os.system_time(:second)

      base = %{
        "exp" => now + entity.trust_chain_statement_ttl,
        "iat" => now,
        "iss" => issuer(),
        "jwks" => jwks,
        "sub" => issuer() <> "/federation/federation_entities/#{entity.id}"
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

  defp validate_trust_chain(trust_chain) do
    with {:ok, trust_chain} <- validate_trust_chain_signatures(trust_chain),
         {:ok, trust_chain} <- validate_trust_chain_constraints(trust_chain) do
      {:ok, trust_chain}
    end
  end

  defp validate_trust_chain_signatures(trust_chain) do
    Enum.reduce_while(trust_chain, {:ok, []}, fn statement, {:ok, acc} ->
      with {:ok, %{"jwks" => %{"keys" => [jwk]}}} <- Joken.peek_claims(statement),
           {:ok, %{"alg" => alg}} <- Joken.peek_header(statement),
           signer <-
             Joken.Signer.create(alg, %{"pem" => JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem()}),
           {:ok, _claims} <- Entity.Token.verify_and_validate(statement, signer) do
        {:cont, {:ok, acc ++ [statement]}}
      else
        _ ->
          case Joken.peek_claims(statement) do
            {:ok, %{"sub" => sub}} ->
              {:halt, {:error, "Trust chain is invalid at #{sub}"}}

            _ ->
              {:halt, {:error, "Trust chain is invalid."}}
          end
      end
    end)
  end

  defp validate_trust_chain_constraints(trust_chain) do
    Enum.reduce_while(trust_chain, {:ok, []}, fn statement, {:ok, acc} ->
      with {:ok, claims} <- Joken.peek_claims(statement),
           :ok <- validate_constraints(trust_chain -- acc, statement, claims["constraints"]) do
        {:cont, {:ok, acc ++ [statement]}}
      else
        _ ->
          case Joken.peek_claims(statement) do
            {:ok, %{"sub" => sub}} ->
              {:halt, {:error, "Trust chain is invalid at #{sub}."}}

            _ ->
              {:halt, {:error, "Trust chain is invalid."}}
          end
      end
    end)
  end

  defp validate_constraints(
         trust_chain,
         statement,
         %{"max_path_length" => max_path_length} = constraints
       ) do
    case Enum.count(trust_chain) > max_path_length do
      true ->
        {:error, "Trust chain depth is invalid."}

      false ->
        validate_constraints(trust_chain, statement, Map.delete(constraints, "max_path_length"))
    end
  end

  defp validate_constraints(
         trust_chain,
         statement,
         %{"naming_constraints" => %{"permitted" => permitted}} = constraints
       ) do
    with :ok <-
           Enum.reduce_while(trust_chain, :ok, fn current, _acc ->
             with {:ok, %{"sub" => sub}} <- Joken.peek_claims(current),
                  true <-
                    Enum.any?(permitted, fn base ->
                      Regex.match?(~r[^#{base}], sub)
                    end) do
               {:cont, :ok}
             else
               _ ->
                 {:halt, {:error, "Trust chain invalid, server is not permitted."}}
             end
           end) do
      validate_constraints(trust_chain, statement, %{
        constraints
        | "naming_constraints" => Map.delete(constraints["naming_constraints"], "permitted")
      })
    end
  end

  defp validate_constraints(
         trust_chain,
         statement,
         %{"naming_constraints" => %{"excluded" => excluded}} = constraints
       ) do
    with :ok <-
           Enum.reduce_while(trust_chain, :ok, fn current, _acc ->
             with {:ok, %{"sub" => sub}} <- Joken.peek_claims(current),
                  true <-
                    Enum.any?(excluded, fn base ->
                      Regex.match?(~r[^#{base}], sub)
                    end) do
               {:halt, {:error, "Trust chain invalid, server is excluded."}}
             else
               _ ->
               {:cont, :ok}
             end
           end) do
      validate_constraints(trust_chain, statement, %{
        constraints
        | "naming_constraints" => Map.delete(constraints["naming_constraints"], "excluded")
      })
    end
  end

  defp validate_constraints(
         trust_chain,
         statement,
         %{"naming_constraints" => %{}} = constraints
       ) do
    validate_constraints(trust_chain, statement, Map.delete(constraints, "naming_constraints"))
  end

  defp validate_constraints(_trust_chain, _statement, %{}), do: :ok

  defp validate_constraints(_trust_chain, _statement, nil), do: :ok
end
