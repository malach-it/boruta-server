defmodule BorutaWeb.Openid.JwksController do
  @behaviour Boruta.Openid.JwksApplication

  alias Boruta.Openid
  alias BorutaWeb.OpenidView

  use BorutaWeb, :controller

  def jwks_index(conn, _params) do
    Openid.jwks(conn, __MODULE__)
  end

  @impl Boruta.Openid.JwksApplication
  def jwk_list(conn, jwk_keys) do
    conn
    |> put_view(OpenidView)
    |> render("jwks.json", keys: jwk_keys)
  end
end
