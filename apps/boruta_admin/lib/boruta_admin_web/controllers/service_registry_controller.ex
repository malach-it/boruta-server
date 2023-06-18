defmodule BorutaAdminWeb.ServiceRegistryController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaGateway.ServiceRegistry

  plug(:authorize, ["upstreams:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def node_list(conn, _params) do
    nodes = ServiceRegistry.list_nodes()

    render(conn, "nodes.json", nodes: nodes)
  end
end
