defmodule BorutaFederationWeb.OpenidView do
  use BorutaFederationWeb, :view

  alias BorutaFederation.TrustChains
  alias BorutaFederation.FederationEntities

  def render("well_known.jwt", _params) do
    with {:ok, well_known, _claims} <- TrustChains.sign(
      %{
        federation_fetch_endpoint: Routes.fetch_url(BorutaFederationWeb.Endpoint, :fetch),
        federation_resolve_endpoint: Routes.resolve_url(BorutaFederationWeb.Endpoint, :resolve)
      },
      FederationEntities.list_entities() |> List.first()
    ) do
      well_known
    end
  end
end
