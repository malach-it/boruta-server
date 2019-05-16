defmodule Authable.GrantType.Implicit do
  @moduledoc """
  Implicit grant type for OAuth2 Authorization Server
  """

  use Authable.RepoBase
  import Authable.Config, only: [repo: 0, app_scopes: 0]
  import Authable.GrantType.Base
  alias Authable.GrantType.Error, as: GrantTypeError

  @behaviour Authable.GrantType
  @grant_type "client_credentials"

  @doc """
  Authorize client for 'client owner' using client credentials.

  For authorization, authorize function requires a map contains 'client_id' and
  'client_secret'. With valid credentials; it automatically creates
  access_token and refresh_token(if enabled via config) then it returns
  `Authable.Model.Token` struct, otherwise `{:error, Map, :http_status_code}`.

  ## Examples

  # With OAuth2 optional scope
  Authable.GrantType.ClientCredentials.authorize(%{
  "client_id" => "52024ca6-cf1d-4a9d-bfb6-9bc5023ad56e",
  "client_secret" => "Wi7Y_Q5LU4iIwJArgqXq2Q",
  "scope" => "read"
  %})

  # Without OAuth2 optional scope
  Authable.GrantType.ClientCredentials.authorize(%{
  "client_id" => "52024ca6-cf1d-4a9d-bfb6-9bc5023ad56e",
  "client_secret" => "Wi7Y_Q5LU4iIwJArgqXq2Q"
  %})
  """
  def authorize(%{
    "user" => user,
    "redirect_uri" => redirect_uri,
    "client_id" => client_id,
    "scope" => scopes
  }) do
    client = repo().get_by(@client, id: client_id, redirect_uri: redirect_uri)
    create_tokens(user, client, scopes)
  end

  def authorize(%{
    "user" => user,
    "redirect_uri" => redirect_uri,
    "client_id" => client_id
  }) do
    client = repo().get_by(@client, id: client_id, redirect_uri: redirect_uri)
    create_tokens(user, client, app_scopes())
  end

  def authorize(_) do
    GrantTypeError.invalid_request(
      "Request must include at least client_id, redirect_uri parameters."
    )
  end

  defp create_tokens(user, nil, _),
  do: GrantTypeError.invalid_client("Invalid client id or redirect_uri.")

  defp create_tokens(user, client, scopes) do
    {:ok, client}
    |> validate_token_scope(scopes)
    |> create_oauth2_tokens(scopes, user)
  end

  defp create_oauth2_tokens({:error, err, code}, _, _), do: {:error, err, code}

  defp create_oauth2_tokens({:ok, client}, scopes, user),
  do: create_oauth2_tokens(user.id, @grant_type, client.id, scopes)

  defp validate_token_scope({:ok, client}, ""), do: {:ok, client}

  defp validate_token_scope({:ok, client}, required_scopes) do
    scopes = Authable.Utils.String.comma_split(app_scopes())
    required_scopes = Authable.Utils.String.comma_split(required_scopes)

    if Authable.Utils.List.subset?(scopes, required_scopes) do
      {:ok, client}
    else
      GrantTypeError.invalid_scope(scopes)
    end
  end
end
