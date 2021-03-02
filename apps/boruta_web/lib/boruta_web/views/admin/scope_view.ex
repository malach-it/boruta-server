defmodule BorutaWeb.Admin.ScopeView do
  use BorutaWeb, :view
  alias BorutaWeb.Admin.ScopeView

  def render("index.json", %{scopes: scopes}) do
    %{data: render_many(scopes, ScopeView, "scope.json")}
  end

  def render("show.json", %{scope: scope}) do
    %{data: render_one(scope, ScopeView, "scope.json")}
  end

  def render("scope.json", %{scope: scope}) do
    %{id: scope.id,
      name: scope.name,
      label: scope.label,
      public: scope.public}
  end
end
