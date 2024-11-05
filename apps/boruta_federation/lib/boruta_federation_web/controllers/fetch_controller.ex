defmodule BorutaFederationWeb.FetchController do
  @behaviour BorutaFederation.OpenidFederationFetchApplication

  alias BorutaFederationWeb.ErrorView
  use BorutaFederationWeb, :controller

  alias BorutaFederation.OpenidFederation

  def fetch(conn, params) do
    fetch_params = %{
      sub: params["sub"]
    }

    OpenidFederation.fetch(conn, fetch_params, __MODULE__)
  end

  @impl BorutaFederation.OpenidFederationFetchApplication
  def fetch_success(conn, federation_entity_statement) do
    conn
    |> put_resp_header("content-type", "application/entity-statement+jwt")
    |> send_resp(200, federation_entity_statement)
  end

  @impl BorutaFederation.OpenidFederationFetchApplication
  def fetch_failure(conn, error) do
    conn
    |> put_status(error.status)
    |> put_view(ErrorView)
    |> render("error.json", error: error)
  end
end
