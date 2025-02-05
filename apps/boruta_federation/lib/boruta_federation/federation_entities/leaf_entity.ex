defmodule BorutaFederation.FederationEntities.LeafEntity do
  @moduledoc false

  alias BorutaFederation.FederationEntities.FederationEntity

  import Boruta.Config, only: [issuer: 0]

  @federation_configuration_path "/.well-known/openid-federation"

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
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
          case Enum.reduce_while(
            trust_chain ++ [statement],
            {:ok, acc},
            fn statement, {:ok, acc} ->
              # TODO
              {:ok, %{"sub" => sub}} = Joken.peek_claims(statement)

              case fetch_statement(authority, sub) do
                {:ok, statement} ->
                  {:cont, {:ok, acc ++ [statement]}}

                {:error, error} ->
                  {:halt, {:error, error}}
              end
            end
          ) do
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
    with {:ok, %Finch.Response{status: 200, body: configuration}} <- Finch.build(:get, authority["issuer"] <> @federation_configuration_path) |> Finch.request(OpenIDHttpClient),
         # TODO verify configuration signature
         {:ok, %{"federation_resolve_endpoint" => resolve_url}} <- Joken.peek_claims(configuration) do
      case Finch.build(:get, resolve_url <> "?sub=#{authority["sub"]}") |> Finch.request(OpenIDHttpClient) do
        {:ok, %Finch.Response{status: 200, body: statement}} ->
          with {:ok, %{"jwks" => %{"keys" => [jwk]}, "trust_chain" => trust_chain}} <-
            Joken.peek_claims(statement),
               {:ok, %{"alg" => alg}} <- Joken.peek_header(statement),
               {_, pem} <- JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem(),
               signer <- Joken.Signer.create(alg, %{"pem" => pem}),
               {:ok, _claims} <- Token.verify_and_validate(statement, signer) do
            {:ok, statement, trust_chain}
          else
            {:ok, []} ->
              {:ok, statement, []}

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
  end

  defp fetch_statement(authority, sub) do
    with {:ok, %Finch.Response{status: 200, body: configuration}} <- Finch.build(:get, authority["issuer"] <> @federation_configuration_path) |> Finch.request(OpenIDHttpClient),
         # TODO verify configuration signature
         {:ok, %{"federation_fetch_endpoint" => fetch_url}} <- Joken.peek_claims(configuration) do
    with {:ok, %Finch.Response{status: 200, body: statement}} <-
      Finch.build(:get, fetch_url <> "?sub=#{sub}") |> Finch.request(OpenIDHttpClient),
         {:ok, %{"jwks" => %{"keys" => [jwk]}}} <- Joken.peek_claims(statement),
         {:ok, %{"alg" => alg}} <- Joken.peek_header(statement),
         {_, pem} <- JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem(),
         signer <- Joken.Signer.create(alg, %{"pem" => pem}),
         {:ok, _claims} <- Token.verify_and_validate(statement, signer) do
      {:ok, statement}
    else
      _ ->
        {:error, "Could not fetch #{authority["issuer"]} statement"}
    end
    else
      _ ->
        {:error, "Could not resolve #{authority["issuer"]} configuration."}
    end
  end
end
