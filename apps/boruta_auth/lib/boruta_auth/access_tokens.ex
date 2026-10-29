defmodule BorutaAuth.AccessTokens do
  @moduledoc false
  @behaviour Boruta.Oauth.AccessTokens

  alias Boruta.Oauth.{Client, ResourceOwner, Token}

  @cached_prefix "gateway-basic."

  def create_cached(params, credentials \\ nil)

  def create_cached(
        %{client: %Client{access_token_ttl: ttl}, resource_owner: %ResourceOwner{} = owner} =
          params,
        credentials
      )
      when is_integer(ttl) and ttl > 0 do
    value = cached_value(params, credentials)
    cache = Boruta.Config.cache_backend()
    key = {Token, :value, value}

    case cache.get!(key) do
      %Token{} = token -> {:ok, token}
      nil -> insert_cached(params, owner, ttl, value, key)
    end
  end

  defp insert_cached(params, owner, ttl, value, key) do
    token = %Token{
      id: Ecto.UUID.generate(),
      type: "access_token",
      value: value,
      client: params.client,
      resource_owner: owner,
      sub: owner.sub,
      scope: params.scope,
      inserted_at: DateTime.utc_now(),
      expires_at: System.os_time(:second) + ttl
    }

    case Boruta.Config.cache_backend().put_new(key, token, ttl: ttl * 1000) do
      {:ok, true} ->
        {:ok, token}

      {:ok, false} ->
        case Boruta.Config.cache_backend().get!(key) do
          %Token{} = cached -> {:ok, cached}
          nil -> insert_cached(params, owner, ttl, value, key)
        end

      {:error, _} = error ->
        error
    end
  end

  defp cached_value(_params, nil),
    do: @cached_prefix <> Boruta.TokenGenerator.generate()

  defp cached_value(params, {username, password}) do
    secret =
      :boruta_identity
      |> Application.fetch_env!(BorutaIdentityWeb.Endpoint)
      |> Keyword.fetch!(:secret_key_base)

    context =
      {"gateway-basic-v1", username, password, params.resource_owner.sub, params.client.id,
       params.client.access_token_ttl, params.scope |> String.split() |> Enum.sort()}

    digest = :crypto.mac(:hmac, :sha256, secret, :erlang.term_to_binary(context))
    @cached_prefix <> Base.url_encode64(digest, padding: false)
  end

  @impl true
  def get_by(value: @cached_prefix <> _ = value) do
    # Cache-only tokens must never fall back to database lookup after expiration/revocation.
    Boruta.Config.cache_backend().get!({Token, :value, value})
  end

  def get_by(refresh_token: @cached_prefix <> _), do: nil
  defdelegate get_by(params), to: Boruta.Ecto.AccessTokens

  @impl true
  defdelegate create(params, options), to: Boruta.Ecto.AccessTokens

  @impl true
  def revoke(%Token{value: @cached_prefix <> _} = token) do
    with :ok <- Boruta.Config.cache_backend().delete({Token, :value, token.value}) do
      {:ok, %{token | revoked_at: DateTime.utc_now()}}
    end
  end

  defdelegate revoke(token), to: Boruta.Ecto.AccessTokens

  @impl true
  defdelegate revoke_refresh_token(token), to: Boruta.Ecto.AccessTokens
end
