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
      redirect_uri: client.redirect_uri
    }
  end
end
