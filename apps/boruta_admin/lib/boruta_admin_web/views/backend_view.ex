defmodule BorutaAdminWeb.BackendView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.BackendView

  def render("index.json", %{backends: backends}) do
    %{data: render_many(backends, BackendView, "backend.json")}
  end

  def render("show.json", %{backend: backend}) do
    %{data: render_one(backend, BackendView, "backend.json")}
  end

  def render("backend.json", %{backend: backend}) do
    %{
      id: backend.id,
      name: backend.name,
      type: backend.type
    }
  end
end
