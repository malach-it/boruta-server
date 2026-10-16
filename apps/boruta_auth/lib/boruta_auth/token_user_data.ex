defmodule BorutaAuth.TokenUserData do
  @moduledoc """
  Stores wallet-presented user data on OAuth tokens.
  """

  alias Boruta.Ecto.Token
  alias Boruta.Openid.VerifiablePresentations
  alias BorutaAuth.Repo

  def store(id, vp_token) when is_binary(vp_token) and vp_token != "" do
    store(id, vp_token, nil)
  end

  def store(_id, _vp_token), do: {:error, :bad_request}

  def store(id, vp_token, client_id) when is_binary(vp_token) and vp_token != "" do
    with %Token{} = token <- Repo.get(Token, id),
         :ok <- authorize_token_client(token, client_id),
         {:ok, confirmation_jwk} <- confirmation_jwk(token),
         {:ok, user_data} <-
           user_data_from_jwt(vp_token, confirmation_jwk, get_nonce(token), token.client_id),
         {:ok, %{num_rows: 1}} <- update(token.id, user_data) do
      {:ok, Repo.preload(token, :client)}
    else
      nil -> {:error, :not_found}
      {:ok, %{num_rows: 0}} -> {:error, :bad_request}
      _error -> {:error, :bad_request}
    end
  end

  def store(_id, _vp_token, _client_id), do: {:error, :bad_request}

  def get(%Token{id: id}) do
    case Repo.query("select user_data from oauth_tokens where id = $1", [dump_uuid(id)]) do
      {:ok, %{rows: [[user_data]]}} -> user_data
      _ -> nil
    end
  end

  def ensure_nonce(%Token{id: id} = token) do
    existing_nonce = get_nonce(token)

    if is_binary(existing_nonce) and existing_nonce != "" do
      existing_nonce
    else
      nonce = nonce_value()

      Repo.query(
        "update oauth_tokens set user_data_nonce = $2, updated_at = now() where id = $1 and user_data_nonce is null",
        [dump_uuid(id), nonce]
      )

      get_nonce(token)
    end
  end

  def get_nonce(%Token{id: id}) do
    case Repo.query("select user_data_nonce from oauth_tokens where id = $1", [dump_uuid(id)]) do
      {:ok, %{rows: [[nonce]]}} -> nonce
      _ -> nil
    end
  end

  defp update(token_id, user_data) do
    Repo.query(
      "update oauth_tokens set user_data = $2, updated_at = now() where id = $1 and user_data is null",
      [dump_uuid(token_id), user_data]
    )
  end

  defp dump_uuid(id) when is_binary(id), do: Ecto.UUID.dump!(id)

  defp nonce_value do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp authorize_token_client(%Token{client_id: client_id}, client_id), do: :ok

  defp authorize_token_client(_token, _client_id), do: {:error, :bad_request}

  defp confirmation_jwk(%Token{id_token: id_token}) when is_binary(id_token) and id_token != "" do
    with {:ok, claims} <- verified_claims(id_token),
         %{"cnf" => %{"jwk" => jwk}} when is_map(jwk) <- claims do
      {:ok, jwk}
    else
      _error -> {:error, :confirmation_key_not_found}
    end
  end

  defp confirmation_jwk(_token), do: {:error, :confirmation_key_not_found}

  defp user_data_from_jwt(jwt, confirmation_jwk, expected_nonce, expected_audience) do
    with {:ok, claims} <- verified_claims(jwt),
         :ok <- validate_nonce(claims, expected_nonce),
         :ok <- validate_audience(claims, expected_audience) do
      user_data_from_claims(claims, jwt, confirmation_jwk)
    end
  end

  defp validate_nonce(%{"nonce" => nonce}, nonce) when is_binary(nonce) and nonce != "", do: :ok

  defp validate_nonce(_claims, _expected_nonce), do: {:error, :invalid_nonce}

  defp validate_audience(%{"aud" => audience}, audience)
       when is_binary(audience) and audience != "",
       do: :ok

  defp validate_audience(%{"aud" => audiences}, audience)
       when is_list(audiences) and is_binary(audience) do
    if audience in audiences, do: :ok, else: {:error, :invalid_audience}
  end

  defp validate_audience(_claims, _expected_audience), do: {:error, :invalid_audience}

  defp verified_claims(jwt) do
    with {:ok, %{"alg" => alg} = headers} <- Joken.peek_header(jwt),
         {:ok, _jwk, claims} <- VerifiablePresentations.verify_jwt(extract_key(headers), alg, jwt) do
      {:ok, claims}
    end
  end

  defp verified_claims(jwt, confirmation_jwk) do
    with {:ok, %{"alg" => alg}} <- Joken.peek_header(jwt),
         {:ok, _jwk, claims} <-
           VerifiablePresentations.verify_jwt({:jwk, confirmation_jwk}, alg, jwt) do
      {:ok, claims}
    end
  end

  defp user_data_from_claims(%{"user_data" => user_data}, jwt, confirmation_jwk)
       when is_map(user_data) do
    with {:ok, _claims} <- verified_claims(jwt, confirmation_jwk) do
      {:ok, user_data}
    end
  end

  defp user_data_from_claims(%{"hook_input" => hook_input}, jwt, confirmation_jwk)
       when is_map(hook_input) do
    with {:ok, _claims} <- verified_claims(jwt, confirmation_jwk) do
      {:ok, hook_input}
    end
  end

  defp user_data_from_claims(
         %{"vp" => %{"verifiableCredential" => credentials}},
         _jwt,
         confirmation_jwk
       ) do
    credentials
    |> List.wrap()
    |> Enum.find_value({:error, :user_data_not_found}, fn credential ->
      case user_data_from_credential(credential, confirmation_jwk) do
        {:ok, user_data} -> {:ok, user_data}
        _error -> nil
      end
    end)
  end

  defp user_data_from_claims(_claims, _jwt, _confirmation_jwk), do: {:error, :user_data_not_found}

  defp user_data_from_credential(credential, confirmation_jwk) when is_binary(credential) do
    with {:ok, claims} <- verified_claims(credential, confirmation_jwk) do
      user_data_from_verified_credential_claims(claims)
    end
  end

  defp user_data_from_credential(_credential, _confirmation_jwk),
    do: {:error, :user_data_not_found}

  defp user_data_from_verified_credential_claims(%{"user_data" => user_data})
       when is_map(user_data) do
    {:ok, user_data}
  end

  defp user_data_from_verified_credential_claims(%{"hook_input" => hook_input})
       when is_map(hook_input) do
    {:ok, hook_input}
  end

  defp user_data_from_verified_credential_claims(_claims), do: {:error, :user_data_not_found}

  defp extract_key(%{"jwk" => jwk}), do: {:jwk, jwk}
  defp extract_key(%{"kid" => did}), do: {:did, did}
  defp extract_key(_headers), do: {:error, "No proof key material found in JWT headers"}
end
