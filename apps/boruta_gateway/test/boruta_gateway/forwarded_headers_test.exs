defmodule BorutaGateway.ForwardedHeadersTest do
  use ExUnit.Case, async: true

  alias BorutaGateway.ForwardedHeaders

  test "replaces spoofed forwarding headers and preserves the original Basic value" do
    payload =
      "POST /users HTTP/1.1\r\nHost: admin.localhost:8082\r\n" <>
        "aUtHoRiZaTiOn: bAsIc YWxpY2U6cGFzc3dvcmQ=\r\n" <>
        "Forwarded: for=spoofed\r\nforwarded: proto=spoofed\r\n" <>
        "X-Forwarded-Authorization: Bearer spoofed\r\n\r\n" <>
        "Forwarded: body-data\r\nAuthorization: body-data"

    result = ForwardedHeaders.put_basic(payload, ~c"127.0.0.1", :http)
    [header, body] = String.split(result, "\r\n\r\n", parts: 2)

    assert header =~ ~s(Forwarded: for=127.0.0.1;proto=http;host="admin.localhost:8082")
    assert header =~ "X-Forwarded-Authorization: bAsIc YWxpY2U6cGFzc3dvcmQ="
    assert length(Regex.scan(~r/(?:^|\r\n)forwarded:/i, header)) == 1
    refute header =~ ~r/(?:^|\r\n)authorization:/i
    refute header =~ "spoofed"
    assert body == "Forwarded: body-data\r\nAuthorization: body-data"
  end

  test "quotes IPv6 and host values for the TLS client connection" do
    result =
      ForwardedHeaders.put_basic(
        "GET / HTTP/1.1\r\nHost: [::1]:8443\r\nAuthorization: Basic YTpi\r\n\r\n",
        ~c"2001:db8::1",
        :https
      )

    assert result =~ ~s(Forwarded: for="[2001:db8::1]";proto=https;host="[::1]:8443")
  end

  test "escapes quoted host values and handles an unknown peer without a host" do
    result =
      ForwardedHeaders.put_basic(
        "GET / HTTP/1.0\r\nAuthorization: Basic YTpi\r\n\r\n",
        :unknown,
        :http
      )

    assert result =~ "Forwarded: for=unknown;proto=http\r\n"

    result =
      ForwardedHeaders.put_basic(
        "GET / HTTP/1.1\r\nHost: host\"\\value\r\nAuthorization: Basic YTpi\r\n\r\n",
        ~c"127.0.0.1",
        :http
      )

    assert result =~ ~s(host="host\\\"\\\\value")
  end
end
