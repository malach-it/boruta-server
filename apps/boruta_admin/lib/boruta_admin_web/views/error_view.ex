defmodule BorutaAdminWeb.ErrorView do
  use BorutaAdminWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  def render("404.json", _assigns) do
    %{
      code: "NOT_FOUND",
      message: "The requested resource could not be found."
    }
  end

  def render("401.json", _assigns) do
    %{
      code: "UNAUTHORIZED",
      message: "You are unauthorized to access this resource."
    }
  end

  def render("403.json", _assigns) do
    %{
      code: "FORBIDDEN",
      message: "You are forbidden to access this resource."
    }
  end
end
