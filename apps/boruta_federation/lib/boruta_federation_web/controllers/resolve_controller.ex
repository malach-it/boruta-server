defmodule BorutaFederationWeb.ResolveController do
  @behaviour BorutaFederation.OpenidFederationResolveApplication

  alias BorutaFederationWeb.ErrorView
  use BorutaFederationWeb, :controller

  alias BorutaFederation.OpenidFederation

  def resolve(conn, params) do
    resolve_params = %{
      sub: params["sub"],
      anchor: params["anchor"]
    }

    OpenidFederation.resolve(conn, resolve_params, __MODULE__)
  end

  @impl BorutaFederation.OpenidFederationResolveApplication
  def resolve_success(conn, federation_entity_statement) do
    conn
    |> put_resp_header("content-type", "application/resolve-response+jwt")
    |> send_resp(200, federation_entity_statement)
  end

  @impl BorutaFederation.OpenidFederationResolveApplication
  def resolve_failure(conn, error) do
    conn
    |> put_status(error.status)
    |> put_view(ErrorView)
    |> render("error.json", error: error)
  end
end
