defmodule BorutaAdminWeb.IdentityProviderView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.IdentityProviderView

  def render("index.json", %{identity_providers: identity_providers}) do
    %{data: render_many(identity_providers, IdentityProviderView, "identity_provider.json")}
  end

  def render("show.json", %{identity_provider: identity_provider}) do
    %{data: render_one(identity_provider, IdentityProviderView, "identity_provider.json")}
  end

  def render("show_template.json", %{template: template}) do
    %{data: render_one(template, IdentityProviderView, "template.json", template: template)}
  end

  def render("identity_provider.json", %{identity_provider: identity_provider}) do
    %{
      id: identity_provider.id,
      name: identity_provider.name,
      type: identity_provider.type,
      choose_session: identity_provider.choose_session,
      registrable: identity_provider.registrable,
      user_editable: identity_provider.user_editable,
      consentable: identity_provider.consentable,
      confirmable: identity_provider.confirmable
    }
  end

  def render("template.json", %{template: template}) do
    %{
      id: template.id,
      content: template.content,
      type: template.type,
      identity_provider_id: template.identity_provider_id
    }
  end
end
