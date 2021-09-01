defmodule BorutaWeb.UserView do
  use BorutaWeb, :view

  alias Boruta.Oauth.ResourceOwner
  alias BorutaWeb.UserView

  def render("current.json", %{user: user}) do
    %{
      data: %{
        id: user.id,
        email: user.email
      }
    }
  end
end
