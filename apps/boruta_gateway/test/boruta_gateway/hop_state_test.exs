defmodule BorutaGateway.HopStateTest do
  use ExUnit.Case, async: true

  alias BorutaGateway.HopState

  @request "POST / HTTP/1.1\r\nHost: example.test\r\nContent-Length: 4\r\n\r\n" <>
             <<0, 255, 1, 2>>

  test "multiplies fingerprints, preserves binary bodies and rejects a returning node" do
    assert {:ok, first} = HopState.advance(@request, 6)
    assert first =~ "X-Hop-State: #{encoded(6)}\r\n"
    assert {:ok, second} = HopState.advance(first, 10)
    assert second =~ "X-Hop-State: #{encoded(60)}\r\n"
    assert String.ends_with?(second, <<0, 255, 1, 2>>)
    assert {:error, :routing_loop} = HopState.advance(second, 6)
    assert {:error, :routing_loop} = HopState.advance(second, 10)
    assert {:ok, third} = HopState.advance(second, 7)
    assert third =~ "X-Hop-State: #{encoded(420)}\r\n"
  end

  test "accepts the initial product and case-insensitive header names" do
    assert {:ok, payload} = HopState.advance(request(encoded(1)), 3)
    assert payload =~ "X-Hop-State: #{encoded(3)}\r\n"
    assert {:ok, payload} = HopState.advance(request(encoded(15)), 7)
    assert payload =~ "X-Hop-State: #{encoded(105)}\r\n"
    assert length(Regex.scan(~r/\r\nx-hop-state:/i, payload)) == 1
  end

  test "rejects an existing square of the current node fingerprint" do
    assert {:error, :routing_loop} = HopState.advance(request(encoded(45)), 3)
  end

  test "rejects malformed and duplicate product headers" do
    for value <- [
          "",
          "0",
          "-1",
          "+1",
          "01",
          "3,5",
          "1.5",
          "abc",
          "3 5",
          "AA==",
          "AAM=",
          "Ax==",
          "Aw",
          "Aw==,BQ=="
        ] do
      assert {:error, :invalid_hop_state} = HopState.advance(request(value), 7)
    end

    assert {:error, :invalid_hop_state} =
             HopState.advance(
               "GET / HTTP/1.1\r\nx-hop-state: Aw==\r\nX-HOP-STATE: BQ==\r\n\r\n",
               7
             )
  end

  test "bounds incoming and outgoing product sizes" do
    assert {:error, :invalid_hop_state} =
             HopState.advance(request(Base.encode64(:binary.copy(<<255>>, 1_876))), 2)

    assert {:error, :routing_loop} =
             HopState.advance(request(Base.encode64(:binary.copy(<<255>>, 1_875))), 2)
  end

  test "accepts a product at the encoded size limit" do
    value = Base.encode64(:binary.copy(<<255>>, 1_874))
    assert {:ok, payload} = HopState.advance(request(value), 2)
    [_, outgoing] = Regex.run(~r/X-Hop-State: ([^\r]+)/, payload)
    assert byte_size(outgoing) == 2_500
    assert {:ok, binary} = Base.decode64(outgoing)

    assert :binary.decode_unsigned(binary) ==
             :binary.decode_unsigned(:binary.copy(<<255>>, 1_874)) * 2
  end

  test "shared factors can reject an unvisited fingerprint" do
    assert {:ok, first} = HopState.advance(@request, 6)
    assert {:ok, second} = HopState.advance(first, 35)
    assert second =~ "X-Hop-State: #{encoded(210)}\r\n"
    assert {:error, :routing_loop} = HopState.advance(second, 10)
  end

  defp encoded(value), do: value |> :binary.encode_unsigned() |> Base.encode64()

  defp request(value), do: "GET / HTTP/1.1\r\nx-hop-state: #{value}\r\n\r\n"
end
