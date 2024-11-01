defmodule BorutaAdminWeb.FederationEntityView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.FederationEntityView

  def render("index.json", %{entities: entities}) do
    %{data: render_many(entities, FederationEntityView, "entity.json")}
  end

  def render("show.json", %{entity: entity}) do
    %{data: render_one(entity, FederationEntityView, "entity.json")}
  end

  def render("entity.json", %{federation_entity: entity}) do
    %{
      id: entity.id,
      type: entity.type,
      trust_chain_statement_alg: entity.trust_chain_statement_alg,
      organization_name: entity.organization_name,
      public_key: entity.public_key
    }
  end
end
