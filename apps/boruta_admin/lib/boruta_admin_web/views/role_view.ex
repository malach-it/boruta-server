defmodule BorutaAdminWeb.RoleView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.RoleView

  def render("index.json", %{roles: roles}) do
    %{data: render_many(roles, RoleView, "role.json")}
  end

  def render("show.json", %{role: role}) do
    %{data: render_one(role, RoleView, "role.json")}
  end

  def render("role.json", %{role: role}) do
    %{id: role.id,
      name: role.name,
      scopes:
        Enum.map(role.scopes, fn scope ->
          %{
            id: scope.id,
            name: scope.name,
            public: scope.public
          }
        end)
    }
  end
end
