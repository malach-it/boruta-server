defmodule BorutaFederationWeb.OpenidController do
  use BorutaFederationWeb, :controller

  def well_known(conn, _params) do
    render(conn, "well_known.jwt")
  end
end
