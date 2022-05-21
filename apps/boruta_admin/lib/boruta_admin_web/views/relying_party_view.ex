defmodule BorutaAdminWeb.RelyingPartyView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.RelyingPartyView

  def render("index.json", %{relying_parties: relying_parties}) do
    %{data: render_many(relying_parties, RelyingPartyView, "relying_party.json")}
  end

  def render("show.json", %{relying_party: relying_party}) do
    %{data: render_one(relying_party, RelyingPartyView, "relying_party.json")}
  end

  def render("show_template.json", %{template: template}) do
    %{data: render_one(template, RelyingPartyView, "template.json", template: template)}
  end

  def render("relying_party.json", %{relying_party: relying_party}) do
    %{
      id: relying_party.id,
      name: relying_party.name,
      type: relying_party.type,
      choose_session: relying_party.choose_session,
      registrable: relying_party.registrable,
      user_editable: relying_party.user_editable,
      consentable: relying_party.consentable,
      confirmable: relying_party.confirmable
    }
  end

  def render("template.json", %{template: template}) do
    %{
      id: template.id,
      content: template.content,
      type: template.type,
      relying_party_id: template.relying_party_id
    }
  end
end
