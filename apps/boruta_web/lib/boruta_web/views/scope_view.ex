defmodule BorutaWeb.ScopeView do
  use BorutaWeb, :view
  alias BorutaWeb.ScopeView

  def render("index.json", %{scopes: scopes}) do
    %{data: render_many(scopes, ScopeView, "scope.json")}
  end

  def render("show.json", %{scope: scope}) do
    %{data: render_one(scope, ScopeView, "scope.json")}
  end

  def render("scope.json", %{scope: scope}) do
    %{id: scope.id,
      name: scope.name,
      public: scope.public}
  end
end
