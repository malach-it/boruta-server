defmodule BorutaGateway.Upstreams.ClientTest do
  use ExUnit.Case
  use Plug.Test

  alias BorutaGateway.Upstreams.Client
  alias BorutaGateway.Upstreams.Upstream

  test "should request an external url (httpbin.org/status) given a Plug.Conn" do
    # TODO change for an internal server
    upstream = %Upstream{scheme: "http", host: "httpbin.org", port: 80}
    conn = conn("GET", "/status/418")
           |> put_req_header("authorization", "Bearer test")
    {:ok, %{
      body: body,
      status: status
    }} = Client.request(upstream, conn)

    assert status == 418
    assert body =~ ~r/teapot/
  end

  test "should request an external url (httpbin.org/headers) given a Plug.Conn" do
    # TODO change for an internal server
    upstream = %Upstream{scheme: "http", host: "httpbin.org", port: 80}
    conn = conn("GET", "/headers")
           |> put_req_header("authorization", "Bearer test")
    {:ok, %{
      body: body,
      status: status
    }} = Client.request(upstream, conn)

    assert status == 200

    req_headers = Jason.decode!(body)["headers"]
    assert Enum.any?(req_headers, fn
      ({"Authorization", "Bearer test"}) -> true
      (_) -> false
    end)
    assert Enum.any?(req_headers, fn
      ({"Host", "httpbin.org"}) -> true
      (_) -> false
    end)
  end
end
