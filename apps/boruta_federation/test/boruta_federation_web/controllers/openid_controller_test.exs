defmodule BorutaFederationWeb.OpenidControllerTest do
  use BorutaFederationWeb.ConnCase

  import BorutaFederation.Factory

  test "GET /.well-known/openid-federation", %{conn: conn} do
    insert(:entity)

    conn = get(conn, "/.well-known/openid-federation")
    assert response(conn, 200) =~ "ey"
  end
end
