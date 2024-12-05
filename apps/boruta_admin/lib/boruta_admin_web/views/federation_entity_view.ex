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
      trust_chain_statement_ttl: entity.trust_chain_statement_ttl,
      trust_mark_logo_uri: entity.trust_mark_logo_uri,
      organization_name: entity.organization_name,
      authorities: entity.authorities,
      is_default: entity.default,
      public_key: entity.public_key
    }
  end
end
