defmodule BorutaAdminWeb.UpstreamViewTest do
  use BorutaAdminWeb.ConnCase, async: true

  import Phoenix.View

  alias BorutaAdminWeb.UpstreamView

  test "node list ignores failed RPC results" do
    response =
      render(UpstreamView, "node_list.json", nodes: ["gateway", {:badrpc, :nodedown}])

    assert response == %{data: ["gateway"]}
    assert Jason.encode!(response) == ~s({"data":["gateway"]})
  end
end
