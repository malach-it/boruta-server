defmodule BorutaAdminWeb.TokenView do
  use BorutaAdminWeb, :view

  alias Boruta.Oauth
  alias BorutaAdminWeb.TokenView
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Admin

  def render(
        "index.json",
        %{
          tokens: tokens,
          page_number: page_number,
          page_size: page_size,
          total_pages: total_pages,
          total_entries: total_entries
        } = assigns
      ) do
    %{
      data:
        Enum.map(tokens, fn token ->
          render(TokenView, "token.json",
            token: token,
            previous_codes: Map.get(Map.get(assigns, :previous_codes, %{}), token.id, [])
          )
        end),
      scopes: Map.get(assigns, :scopes, []),
      types: Map.get(assigns, :types, []),
      type_counts: Map.get(assigns, :type_counts, %{}),
      page_number: page_number,
      page_size: page_size,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{token: token} = assigns) do
    %{
      data:
        render(TokenView, "token.json",
          token: token,
          previous_codes: Map.get(Map.get(assigns, :previous_codes, %{}), token.id, [])
        )
    }
  end

  def render("token.json", %{token: token} = assigns) do
    %{
      id: token.id,
      type: token.type,
      response_type: token.response_type,
      value: token.value,
      refresh_token: token.refresh_token,
      previous_code: token.previous_code,
      previous_codes:
        Enum.map(Map.get(assigns, :previous_codes, []), fn previous_code ->
          render(TokenView, "token.json", token: previous_code, previous_codes: [])
        end),
      previous_token: token.previous_token,
      agent_token: token.agent_token,
      scope: Oauth.Scope.split(token.scope),
      requested_scope: Oauth.Scope.split(token.requested_scope),
      redirect_uri: token.redirect_uri,
      expires_at: token.expires_at,
      revoked_at: token.revoked_at,
      refresh_token_revoked_at: token.refresh_token_revoked_at,
      sub: token.sub,
      user: user(token.sub),
      public_client_id: token.public_client_id,
      client: client(token.client),
      inserted_at: token.inserted_at,
      updated_at: token.updated_at
    }
  end

  defp client(%Boruta.Ecto.Client{} = client) do
    %{
      id: client.id,
      name: client.name
    }
  end

  defp client(_client), do: nil

  defp user(sub) when is_binary(sub) do
    case Admin.get_user(sub) do
      %User{} = user ->
        %{
          id: user.id,
          uid: user.uid,
          username: user.username
        }

      _ ->
        nil
    end
  end

  defp user(_sub), do: nil
end
