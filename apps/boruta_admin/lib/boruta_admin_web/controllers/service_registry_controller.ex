defmodule BorutaAdminWeb.ServiceRegistryController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Node

  plug(:authorize, ["upstreams:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def node_list(conn, _params) do
    nodes = ServiceRegistry.list_nodes()

    render(conn, "nodes.json", nodes: nodes)
  end

  def delete_node(conn, %{"node_id" => node_id}) do
    ip = case ServiceRegistry.get_node(node_id) do
      %Node{ip: ip} -> ip
      _ -> ""
    end

    with :ok <- ServiceRegistry.delete_by_ip!(ip) do
      send_resp(conn, :no_content, "")
    end
  end
end
