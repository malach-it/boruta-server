defmodule BorutaFederation.FederationEntities.Entity do
  @moduledoc false

  alias BorutaFederation.Cache
  alias BorutaFederation.FederationEntities.FederationEntity

  import Boruta.Config, only: [issuer: 0]

  @federation_configuration_path "/.well-known/openid-federation"
  @resolve_timeout 120_000

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
  end

  @spec constraints(entity :: FederationEntity.t()) :: {:ok, constraints :: map()}
  def constraints(entity) do
    constraints = %{}

    constraints = case entity.max_depth do
      nil ->
        constraints
      max_depth ->
        Map.put(constraints, "max_path_length", max_depth)
    end

    {:ok, constraints}
  end

  @spec metadata(entity :: FederationEntity.t()) :: {:ok, metadata :: map()}
  def metadata(entity) do
    {:ok,
     %{
       "openid_provider" => %{
         "issuer" => issuer(),
         "organization_name" => entity.organization_name
       }
     }}
  end

  @spec jwks(entity :: FederationEntity.t()) :: {:ok, jwks :: map()}
  def jwks(entity) do
    {:ok, %{"keys" => [JOSE.JWK.from_pem(entity.public_key) |> JOSE.JWK.to_map() |> elem(1)]}}
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
  def resolve_parents_chain(entity) do
    Enum.reduce_while(entity.authorities, {:ok, []}, fn authority, {:ok, acc} ->
      case resolve_chain(authority) do
        {:ok, statement, trust_chain} ->
          case fetch_chain_statements(authority, trust_chain ++ [statement]) do
            {:ok, chain} ->
              {:cont, {:ok, acc ++ chain}}

            {:error, error} ->
              {:halt, {:error, error}}
          end

        _ ->
          {:halt, {:error, "Could not fetch parent chain."}}
      end
    end)
  end

  defp resolve_chain(authority) do
    case Cache.get({:entity_resolve_statement, authority}) do
      nil ->
        with {:ok, %Finch.Response{status: 200, body: configuration}} <-
               Finch.build(:get, authority["issuer"] <> @federation_configuration_path)
               |> Finch.request(OpenIDHttpClient),
             # TODO verify configuration signature
             {:ok, %{"federation_resolve_endpoint" => resolve_url}} <-
               Joken.peek_claims(configuration) do
          case Finch.build(:get, resolve_url <> "?sub=#{authority["sub"]}")
               |> Finch.request(OpenIDHttpClient, receive_timeout: @resolve_timeout) do
            {:ok, %Finch.Response{status: 200, body: statement}} ->
              with {:ok,
                    %{"exp" => exp, "jwks" => %{"keys" => [jwk]}, "trust_chain" => trust_chain}} <-
                     Joken.peek_claims(statement),
                   {:ok, %{"alg" => alg}} <- Joken.peek_header(statement),
                   {_, pem} <- JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem(),
                   signer <- Joken.Signer.create(alg, %{"pem" => pem}),
                   {:ok, _claims} <- Token.verify_and_validate(statement, signer),
                   :ok <-
                     Cache.put(
                       {:entity_resolve_statement, authority},
                       {statement, trust_chain},
                       ttl: (exp - :os.system_time(:second)) * 1000
                     ) do
                {:ok, statement, trust_chain}
              else
                _ ->
                  {:error, "Could not resolve parent trust chain."}
              end

            _ ->
              {:error, "Could not resolve #{authority["issuer"]} parent trust chain."}
          end
        else
          _ ->
            {:error, "Could not resolve #{authority["issuer"]} configuration."}
        end

      {statement, trust_chain} ->
        {:ok, statement, trust_chain}
    end
  end

  defp fetch_statement(authority, sub) do
    case Cache.get({:entity_fetch_statement, sub}) do
      nil ->
        with {:ok, %Finch.Response{status: 200, body: configuration}} <-
               Finch.build(:get, authority["issuer"] <> @federation_configuration_path)
               |> Finch.request(OpenIDHttpClient),
             # TODO verify configuration signature
             {:ok, %{"federation_fetch_endpoint" => fetch_url}} <-
               Joken.peek_claims(configuration) do
          with {:ok, %Finch.Response{status: 200, body: statement}} <-
                 Finch.build(:get, fetch_url <> "?sub=#{sub}") |> Finch.request(OpenIDHttpClient),
               {:ok, %{"exp" => exp, "jwks" => %{"keys" => [jwk]}}} <-
                 Joken.peek_claims(statement),
               {:ok, %{"alg" => alg}} <- Joken.peek_header(statement),
               {_, pem} <- JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem(),
               signer <- Joken.Signer.create(alg, %{"pem" => pem}),
               {:ok, _claims} <- Token.verify_and_validate(statement, signer),
               :ok <-
                 Cache.put(
                   {:entity_fetch_statement, sub},
                   statement,
                   ttl: (exp - :os.system_time(:second)) * 1000
                 ) do
            {:ok, statement}
          else
            _ ->
              {:error, "Could not fetch #{authority["issuer"]} statement"}
          end
        else
          _ ->
            {:error, "Could not resolve #{authority["issuer"]} configuration."}
        end

      statement ->
        {:ok, statement}
    end
  end

  defp fetch_chain_statements(authority, trust_chain, acc \\ [])

  defp fetch_chain_statements(_authority, _trust_chain, {:error, error}), do: {:error, error}

  defp fetch_chain_statements(_authority, [], acc), do: {:ok, Enum.reverse(acc)}

  defp fetch_chain_statements(authority, [statement|trust_chain] = current, acc) do
    case Joken.peek_claims(statement) do
      {:ok, %{"sub" => sub}} ->
        case fetch_statement(authority, sub) do
          {:ok, statement} ->
            fetch_chain_statements(authority, trust_chain, [statement|acc])

          {:error, error} ->
            fetch_chain_statements(authority, current, {:error, error})
        end
      _ -> fetch_chain_statements(authority, current, {:error, "Invalid trust chain statement."})
    end
  end
end
