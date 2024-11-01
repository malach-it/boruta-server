defmodule BorutaAdminWeb.FederationEntityController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaFederation.FederationEntities
  alias BorutaFederation.FederationEntities.FederationEntity

  plug(:authorize, ["federation-entities:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, _params) do
    entities = FederationEntities.list_entities()

    render(conn, "index.json", entities: entities)
  end

  def create(conn, %{"federation_entity" => entity_params}) do
    with {:ok, %FederationEntity{} = entity} <- FederationEntities.create_entity(entity_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_federation_entity_path(conn, :show, entity))
      |> render("show.json", entity: entity)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, _entity} <- FederationEntities.delete_entity(id) do
      send_resp(conn, :no_content, "")
    end
  end
end
