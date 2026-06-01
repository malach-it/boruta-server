defmodule BorutaAdminWeb.ServiceRegistryView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.ServiceRegistryView

  def render("index.json", %{records: records}) do
    %{data: render_many(records, ServiceRegistryView, "record.json")}
  end

  def render("record.json", %{service_registry: record}) do
    %{
      id: record.id,
      node_name: record.node_name,
      erlang_node_name: record.erlang_node_name,
      ip_address: record.ip_address,
      aliases: record.aliases,
      certificate: record.certificate,
      configuration: record.configuration || %{},
      status: record.status,
      inserted_at: format_timestamp(record.inserted_at),
      updated_at: format_timestamp(record.updated_at)
    }
  end

  defp format_timestamp(nil), do: nil
  defp format_timestamp(timestamp), do: NaiveDateTime.to_iso8601(timestamp)
end
