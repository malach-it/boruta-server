defmodule BorutaFederationWeb.OpenidView do
  use BorutaFederationWeb, :view

  alias BorutaFederation.TrustChains
  alias BorutaFederation.FederationEntities

  def render("well_known.jwt", %{entity: entity}) do
    entity = entity || FederationEntities.list_entities() |> List.first()
    with {:ok, chain_statements} <- apply(String.to_atom(entity.type), :resolve_parents_chain, [entity]),
         {:ok, well_known, _claims} <- TrustChains.sign(
      %{
        federation_fetch_endpoint: Routes.fetch_url(BorutaFederationWeb.Endpoint, :fetch),
        federation_resolve_endpoint: Routes.resolve_url(BorutaFederationWeb.Endpoint, :resolve),
        trust_chain: chain_statements
      },
      entity
    ) do
      well_known
    end
  end
end
