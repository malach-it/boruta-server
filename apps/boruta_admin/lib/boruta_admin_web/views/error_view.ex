defmodule BorutaAdminWeb.ErrorView do
  use BorutaAdminWeb, :view

  def render("400.json", _assigns) do
    %{
      code: "BAD_REQUEST",
      message: "The requested with given parameters cannot be processed.",
      errors: %{
        resource: ["the requested with given parameters cannot be processed."]
      }
    }
  end

  def render("404.json", _assigns) do
    %{
      code: "NOT_FOUND",
      message: "The requested resource could not be found.",
      errors: %{
        resource: ["the requested resource could not be found."]
      }
    }
  end

  def render("401.json", _assigns) do
    %{
      code: "UNAUTHORIZED",
      message: "You are unauthorized to access this resource.",
      errors: %{
        resource: ["you are unauthorized to access this resource."]
      }
    }
  end

  def render("403.json", _assigns) do
    %{
      code: "FORBIDDEN",
      message: "You are forbidden to access this resource.",
      errors: %{
        resource: ["you are forbidden to access this resource."]
      }
    }
  end

  def render("protected_resource.json", _assigns) do
    %{
      code: "FORBIDDEN",
      message: "The resource is write protected.",
      errors: %{
        resource: ["is write protected."]
      }
    }
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
