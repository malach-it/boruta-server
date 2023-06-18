defmodule BorutaAdminWeb.ServiceRegistryView do
  use BorutaAdminWeb, :view

  def render("nodes.json", %{nodes: nodes}) do
    %{
      data:
        Enum.map(nodes, fn node ->
          render(__MODULE__, "node.json", node: node)
        end)
    }
  end

  def render("node.json", %{node: node}) do
    %{id: node.id, ip: node.ip, name: node.name}
  end
end
