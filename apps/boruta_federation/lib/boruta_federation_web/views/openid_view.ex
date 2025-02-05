defmodule BorutaFederationWeb.OpenidView do
  use BorutaFederationWeb, :view

  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.TrustChains
  alias BorutaFederation.FederationEntities

  def render("well_known.jwt", %{entity: entity}) do
    entity = entity || FederationEntities.list_entities() |> List.first()
    with {:ok, well_known, _claims} <- TrustChains.sign(
      %{
        federation_fetch_endpoint: issuer() <> "/federation/fetch",
        federation_resolve_endpoint: issuer() <> "/federation/resolve",
        authority_hints: Enum.map(entity.authorities, &(&1["sub"]))
      },
      entity
    ) do
      well_known
    else
      _ -> ""
    end
  end
end
