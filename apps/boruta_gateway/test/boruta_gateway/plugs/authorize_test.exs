defmodule BorutaGateway.Plug.AuthorizeTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias BorutaGateway.Plug.Authorize
  alias BorutaGateway.Upstreams.Upstream

  describe "call/2" do
    test "treats JSON accept headers with parameters as service requests" do
      conn =
        :get
        |> conn("/resource")
        |> put_req_header("accept", "application/json; charset=utf-8")
        |> assign_upstream(%{
          authorize: true,
          error_content_type: "text/plain",
          unauthorized_response: "missing token"
        })

      conn = Authorize.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "missing token"
      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    end
  end

  defp assign_upstream(conn, attrs) do
    upstream =
      struct(
        Upstream,
        Map.merge(
          %{
            authorize: true,
            required_scopes: %{},
            scheme: "http",
            host: "example.test",
            port: 80,
            uris: ["/"]
          },
          attrs
        )
      )

    assign(conn, :upstream, upstream)
  end
end
