defmodule BorutaAdminWeb.IdentityProviderView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.BackendView

  def render("index.json", %{identity_providers: identity_providers}) do
    %{data: render_many(identity_providers, __MODULE__, "identity_provider.json")}
  end

  def render("show.json", %{identity_provider: identity_provider}) do
    %{data: render_one(identity_provider, __MODULE__, "identity_provider.json")}
  end

  def render("show_template.json", %{template: template}) do
    %{data: render_one(template, __MODULE__, "template.json", template: template)}
  end

  def render("identity_provider.json", %{identity_provider: identity_provider}) do
    %{
      id: identity_provider.id,
      name: identity_provider.name,
      backend: render_one(identity_provider.backend, BackendView, "backend.json", backend: identity_provider.backend),
      backend_id: identity_provider.backend_id,
      choose_session: identity_provider.choose_session,
      totpable: identity_provider.totpable,
      enforce_totp: identity_provider.enforce_totp,
      webauthnable: identity_provider.webauthnable,
      enforce_webauthn: identity_provider.enforce_webauthn,
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
