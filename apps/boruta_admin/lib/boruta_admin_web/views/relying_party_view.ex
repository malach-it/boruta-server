defmodule BorutaAdminWeb.RelyingPartyView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.RelyingPartyView

  def render("index.json", %{relying_parties: relying_parties}) do
    %{data: render_many(relying_parties, RelyingPartyView, "relying_party.json")}
  end

  def render("show.json", %{relying_party: relying_party}) do
    %{data: render_one(relying_party, RelyingPartyView, "relying_party.json")}
  end

  def render("relying_party.json", %{relying_party: relying_party}) do
    %{id: relying_party.id,
      name: relying_party.name,
      type: relying_party.type}
  end
end
