defmodule Boruta.Clients do
  @moduledoc false

  @behaviour Boruta.Oauth.Clients

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth

  @impl Boruta.Oauth.Clients
  def get_by(id: id, secret: secret) do
    with %Boruta.Client{} = client <- repo().get_by(Boruta.Client, id: id, secret: secret) do
      to_oauth_schema(client)
    end
  end
  def get_by(id: id, redirect_uri: redirect_uri) do
    with %Boruta.Client{} = client <- repo()
         .one(from c in Boruta.Client,
           where: c.id == ^id and fragment("? = ANY (redirect_uris)", ^redirect_uri)) do
      to_oauth_schema(client)
    end
  end

  @impl Boruta.Oauth.Clients
  def authorized_scopes(%Oauth.Client{id: id}) do
    case repo().get_by(Boruta.Client, id: id) do
      %Boruta.Client{} = client ->
        client = to_oauth_schema(client)
        client.authorized_scopes
      nil -> []
    end
  end

  def to_oauth_schema(nil), do: nil
  def to_oauth_schema(%Boruta.Client{} = client) do
    client = repo().preload(client, :authorized_scopes)

    struct(Oauth.Client, Map.merge(
      Map.from_struct(client),
      %{authorized_scopes: Enum.map(client.authorized_scopes, fn (scope) ->
        struct(Oauth.Scope, Map.from_struct(scope))
      end)}
    ))
  end
end
