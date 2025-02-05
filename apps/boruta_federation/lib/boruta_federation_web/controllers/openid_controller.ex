defmodule BorutaFederationWeb.OpenidController do
  use BorutaFederationWeb, :controller

  alias BorutaFederation.FederationEntities

  def well_known(conn, params) do
    entity = FederationEntities.get_entity_by_id(params["entity_id"])

    render(conn, "well_known.jwt", entity: entity)
  end
end
