defmodule BorutaWeb.Admin.ClientView do
  use BorutaWeb, :view
  alias BorutaWeb.Admin.ClientView

  def render("index.json", %{clients: clients}) do
    %{data: render_many(clients, ClientView, "client.json")}
  end

  def render("show.json", %{client: client}) do
    %{data: render_one(client, ClientView, "client.json")}
  end

  def render("client.json", %{client: client}) do
    %{
      id: client.id,
      secret: client.secret,
      redirect_uris: client.redirect_uris,
      authorize_scope: client.authorize_scope,
      authorized_scopes: Enum.map(client.authorized_scopes, fn (scope) ->
        %{
          id: scope.id,
          name: scope.name,
          public: scope.public
        }
      end),
      supported_grant_types: client.supported_grant_types
    }
  end
end
