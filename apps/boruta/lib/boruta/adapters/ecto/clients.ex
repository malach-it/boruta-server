defmodule Boruta.Ecto.Clients do
  @moduledoc false

  @behaviour Boruta.Oauth.Clients

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]
  import Boruta.Ecto.OauthMapper, only: [to_oauth_schema: 1]

  alias Boruta.Ecto
  alias Boruta.Oauth

  @impl Boruta.Oauth.Clients
  def get_by(id: id, secret: secret) do
    with %Ecto.Client{} = client <- repo().get_by(Ecto.Client, id: id, secret: secret) do
      to_oauth_schema(client)
    end
  end

  def get_by(id: id, redirect_uri: redirect_uri) do
    with %Ecto.Client{} = client <-
           repo().one(
             from c in Ecto.Client,
               where: c.id == ^id and fragment("? = ANY (redirect_uris)", ^redirect_uri)
           ) do
      to_oauth_schema(client)
    end
  end

  @impl Boruta.Oauth.Clients
  def authorized_scopes(%Oauth.Client{id: id}) do
    case repo().get_by(Ecto.Client, id: id) do
      %Ecto.Client{} = client ->
        client = repo().preload(client, :authorized_scopes)
        Enum.map(
          client.authorized_scopes,
          &to_oauth_schema(&1)
        )

      nil ->
        []
    end
  end
end
