defmodule BorutaFederationWeb.OpenidView do
  use BorutaFederationWeb, :view

  def render("well_known.json", _params) do
    # TODO change to the default entity statement
    %{
      federation_fetch_endpoint: Routes.fetch_url(BorutaFederationWeb.Endpoint, :fetch),
      federation_resolve_endpoint: Routes.resolve_url(BorutaFederationWeb.Endpoint, :resolve)
    }
  end
end
