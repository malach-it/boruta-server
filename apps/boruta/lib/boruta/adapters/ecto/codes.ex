defmodule Boruta.Ecto.Codes do
  @moduledoc false
  @behaviour Boruta.Oauth.Codes

  import Boruta.Config, only: [repo: 0]
  import Boruta.Ecto.OauthMapper, only: [to_oauth_schema: 1]

  alias Boruta.Ecto

  @impl Boruta.Oauth.Codes
  def get_by(value: value, redirect_uri: redirect_uri) do
    repo().get_by(Ecto.Token, type: "code", value: value, redirect_uri: redirect_uri)
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
    changeset =
      Ecto.Token.code_changeset(%Ecto.Token{}, %{
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
end
