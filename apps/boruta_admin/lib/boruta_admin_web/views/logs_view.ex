defmodule BorutaAdminWeb.LogsView do
  use BorutaAdminWeb, :view

  def render("index.json", %{stats: stats}) do
    stats
  end
end
