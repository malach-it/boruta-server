defmodule BorutaGateway.HttpRequestTest do
  use ExUnit.Case

  alias BorutaGateway.HttpRequest

  test "accepts one framed request and reports the remaining body length" do
    assert {:ok, request} =
             HttpRequest.parse(
               "POST / HTTP/1.1\r\nHost: example.test\r\nContent-Length: 4\r\n\r\nab",
               1024
             )

    assert request.header == "POST / HTTP/1.1\r\nHost: example.test\r\nContent-Length: 4"

    assert request.header_payload ==
             "POST / HTTP/1.1\r\nHost: example.test\r\nContent-Length: 4\r\n\r\n"

    assert request.body == "ab"
    assert request.body_remaining == 2
  end

  test "rejects bytes after a bodyless request" do
    assert {:error, :invalid_request} =
             HttpRequest.parse(
               "GET /allowed HTTP/1.1\r\nHost: example.test\r\n\r\n" <>
                 "GET /protected HTTP/1.1\r\nHost: example.test\r\n\r\n",
               1024
             )
  end

  test "rejects ambiguous and unsupported request framing" do
    assert {:error, :multiple_content_lengths} =
             HttpRequest.parse(
               "POST / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n",
               1024
             )

    assert {:error, :unsupported_transfer_encoding} =
             HttpRequest.parse("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n", 1024)
  end

  test "limits incomplete and complete request headers" do
    assert {:error, :headers_too_large} = HttpRequest.parse(String.duplicate("a", 17), 16)

    assert {:error, :headers_too_large} =
             HttpRequest.parse("GET / HTTP/1.1\r\nX-Test: value\r\n\r\n", 16)
  end

  test "does not consume bytes beyond the declared request body" do
    assert {:ok, "ab", 2} = HttpRequest.consume_body("ab", 4)
    assert {:error, :body_too_large} = HttpRequest.consume_body("abcde", 4)
  end
end
