defmodule Boruta.Ecto.AccessTokens do
  @moduledoc false
  @behaviour Boruta.Oauth.AccessTokens

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]
  import Boruta.Ecto.OauthMapper, only: [to_oauth_schema: 1]

  alias Ecto.Changeset
  alias Boruta.Ecto
  alias Boruta.Oauth

  @impl Boruta.Oauth.AccessTokens
  def get_by(value: value) do
    repo().one(
      from t in Ecto.Token,
        left_join: c in assoc(t, :client),
        left_join: u in assoc(t, :resource_owner),
        where: t.type == "access_token" and t.value == ^value
    )
    |> to_oauth_schema()
  end

  def get_by(refresh_token: refresh_token) do
    repo().one(
      from t in Ecto.Token,
        left_join: c in assoc(t, :client),
        left_join: u in assoc(t, :resource_owner),
        where: t.type == "access_token" and t.refresh_token == ^refresh_token
    )
    |> to_oauth_schema()
  end

  @impl Boruta.Oauth.AccessTokens
  def create(
        %{client: client, scope: scope} = params,
        options
      ) do
    resource_owner = params[:resource_owner]
    state = params[:state]
    redirect_uri = params[:redirect_uri]

    token_attributes = %{
      client_id: client.id,
      resource_owner_id: resource_owner && resource_owner.id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope
    }

    changeset =
      apply(
        Ecto.Token,
        changeset_method(options),
        [%Ecto.Token{}, token_attributes]
      )

    with {:ok, token} <- repo().insert(changeset) do
      {:ok, to_oauth_schema(token)}
    end
  end

  defp changeset_method(refresh_token: true), do: :changeset_with_refresh_token
  defp changeset_method(_options), do: :changeset

  @impl Boruta.Oauth.AccessTokens
  def revoke(%Oauth.Token{value: value}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, token} <- repo().get_by(Ecto.Token, value: value)
    |> Changeset.change(revoked_at: now)
    |> repo().update() do
      {:ok, to_oauth_schema(token)}
    end
  end
end
