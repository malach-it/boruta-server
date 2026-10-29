defmodule BorutaAdminWeb.PageControllerTest do
  use BorutaAdminWeb.ConnCase

  test "renders without exposing request bearer tokens", %{conn: conn} do
    conn = conn |> put_req_header("authorization", "Bearer private-token") |> get("/")
    body = html_response(conn, 200)
    assert body =~ "BORUTA_ADMIN_BASIC_AUTH: false"
    refute body =~ "private-token"
    refute body =~ "borutaRequestAuthorization"
    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "signals direct and forwarded Basic authentication without exposing credentials", %{
    conn: conn
  } do
    for header <- ["authorization", "x-forwarded-authorization"] do
      response =
        conn |> put_req_header(header, "Basic dXNlcjpwYXNz") |> get("/users/example/edit")

      body = html_response(response, 200)
      assert body =~ "BORUTA_ADMIN_BASIC_AUTH: true"
      refute body =~ "dXNlcjpwYXNz"
    end
  end

  test "ignores absent and malformed Basic credentials", %{conn: conn} do
    assert html_response(get(conn, "/"), 200) =~ "BORUTA_ADMIN_BASIC_AUTH: false"

    for value <- ["Basic ", "Basic </script>", "Bearer token"] do
      response = conn |> put_req_header("authorization", value) |> get("/")
      assert html_response(response, 200) =~ "BORUTA_ADMIN_BASIC_AUTH: false"
    end
  end
end
