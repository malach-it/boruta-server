defmodule BorutaGateway.BasicAccessTokens do
  @moduledoc false

  alias Boruta.AccessTokensAdapter
  alias Boruta.Oauth.Token
  alias BorutaAuth.TokenGenerator

  def get_or_create(params, _credentials) do
    value = TokenGenerator.generate_basic(params)

    with %Token{} = token <- AccessTokensAdapter.get_by(value: value),
         :ok <- Token.ensure_valid(token) do
      {:ok, token}
    else
      _ ->
        params
        |> Map.put(:authorization_details, [%{"type" => "openid_credential", "format" => "basic_auth"}])
        |> AccessTokensAdapter.create([])
    end
  end
end
