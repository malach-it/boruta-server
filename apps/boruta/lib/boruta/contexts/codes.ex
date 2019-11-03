defmodule Boruta.Codes do
  @moduledoc false
  @behaviour Boruta.Oauth.Codes

  import Boruta.Config, only: [repo: 0]

  alias Boruta.Clients
  alias Boruta.Oauth

  @impl Boruta.Oauth.Codes
  def get_by(value: value, redirect_uri: redirect_uri) do
    repo().get_by(Boruta.Token, type: "code", value: value, redirect_uri: redirect_uri)
    |> to_oauth_schema()
  end

  @impl Boruta.Oauth.Codes
  def create(%{
    client: client,
    resource_owner: resource_owner,
    redirect_uri: redirect_uri,
    scope: scope,
    state: state
  }) do
    changeset = Boruta.Token.code_changeset(%Boruta.Token{}, %{
      client_id: client.id,
      resource_owner_id: resource_owner.id,
      redirect_uri: redirect_uri,
      state: state,
      scope: scope
    })

    with {:ok, token} <- repo().insert(changeset) do
      {:ok, to_oauth_schema(token)}
    end
  end

  def to_oauth_schema(nil), do: nil
  def to_oauth_schema(%Boruta.Token{} = token) do
    token = repo().preload(token, [:client, :resource_owner])
    struct(Oauth.Token, Map.merge(
      Map.from_struct(token),
      %{client: Clients.to_oauth_schema(token.client)}
    ))
  end
end
