defmodule BorutaFederationWeb.OpenidView do
  use BorutaFederationWeb, :view

  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities
  alias BorutaFederation.TrustChains

  def render("well_known.jwt", %{entity: entity}) do
    entity = entity || FederationEntities.list_entities() |> List.first()
    case TrustChains.sign(
      %{
        federation_fetch_endpoint: issuer() <> "/federation/fetch",
        federation_resolve_endpoint: issuer() <> "/federation/resolve",
        authority_hints: Enum.map(entity.authorities, &(&1["sub"]))
      },
      entity
    ) do
      {:ok, well_known, _claims} ->
        String.trim(well_known)
      _ -> ""
    end
  end
end
