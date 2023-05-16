defmodule BorutaWeb.Openid.JwksController do
  @behaviour Boruta.Openid.JwksApplication

  alias Boruta.Openid
  alias BorutaAuth.KeyPairs
  alias BorutaWeb.OpenidView

  use BorutaWeb, :controller

  def jwks_index(conn, _params) do
    Openid.jwks(conn, __MODULE__)
  end

  @impl Boruta.Openid.JwksApplication
  def jwk_list(conn, jwk_keys) do
    global_keys = KeyPairs.list_jwks()

    keys =
      Enum.uniq_by(
        global_keys ++ jwk_keys,
        fn %{"kid" => kid} -> kid end
      )

    conn
    |> put_view(OpenidView)
    |> render("jwks.json", keys: keys)
  end
end
