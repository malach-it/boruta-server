defmodule BorutaAdminWeb.ServiceRegistryController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaGateway.ServiceRegistry

  plug(:authorize, ["upstreams:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, _params) do
    records = ServiceRegistry.list_records()
    render(conn, "index.json", records: records)
  end
end
