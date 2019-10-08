defmodule BorutaWeb.Admin.UserView do
  use BorutaWeb, :view
  alias BorutaWeb.Admin.UserView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email,
      authorized_scopes: Enum.map(user.authorized_scopes, fn (scope) ->
        %{
          id: scope.id,
          name: scope.name,
          public: scope.public
        }
      end)
    }
  end
end
