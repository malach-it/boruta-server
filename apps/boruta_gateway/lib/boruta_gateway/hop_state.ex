defmodule BorutaGateway.HopState do
  @moduledoc """
  Tracks visited nodes as a Base64-encoded binary product in X-Hop-State.

  SHA-256 fingerprints are interpreted as unsigned big-endian integers and
  multiplied into the product (initially 1). The product is encoded as a minimal
  unsigned big-endian binary using standard padded Base64. An incoming product
  divisible by the current node's fingerprint rejects the request with 418. Composite
  fingerprints can share factors, so this check can produce false positives.
  This header is a loop guard, not an authenticated record of the request's route.
  """

  require Record

  Record.defrecordp(
    :certificate,
    :Certificate,
    Record.extract(:Certificate, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :tbs_certificate,
    :TBSCertificate,
    Record.extract(:TBSCertificate, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  alias BorutaGateway.Certificate

  # Bound Base64 decoding and integer multiplication independently of request header limits.
  @max_encoded_bytes 2_500

  def current do
    der = Certificate.ssl_options() |> Keyword.fetch!(:cert)

    case :persistent_term.get({__MODULE__, :fingerprint}, nil) do
      {^der, fingerprint} ->
        fingerprint

      _ ->
        fingerprint = fingerprint(der)
        :persistent_term.put({__MODULE__, :fingerprint}, {der, fingerprint})
        fingerprint
    end
  end

  def fingerprint(der) do
    public_key_info =
      der
      |> :public_key.pkix_decode_cert(:plain)
      |> certificate(:tbsCertificate)
      |> tbs_certificate(:subjectPublicKeyInfo)

    :crypto.hash(:sha256, :public_key.der_encode(:SubjectPublicKeyInfo, public_key_info))
    |> :binary.decode_unsigned()
    # Reserve 0 and 1: neither can track a node through multiplication.
    |> max(2)
  end

  def advance(payload, node_id \\ current()) do
    [header, body] = :binary.split(payload, "\r\n\r\n")
    [request_line | headers] = String.split(header, "\r\n")
    {hop_headers, headers} = Enum.split_with(headers, &hop_header?/1)

    with {:ok, product} <- parse_product(hop_headers),
         false <- rem(product, node_id) == 0,
         value = (product * node_id) |> :binary.encode_unsigned() |> Base.encode64(),
         true <- byte_size(value) <= @max_encoded_bytes do
      header = Enum.join([request_line | headers] ++ ["X-Hop-State: " <> value], "\r\n")
      {:ok, header <> "\r\n\r\n" <> body}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :routing_loop}
    end
  end

  defp parse_product([]), do: {:ok, 1}

  defp parse_product([line]) do
    [_name, value] = String.split(line, ":", parts: 2)
    value = String.trim(value)

    with true <- byte_size(value) <= @max_encoded_bytes,
         {:ok, <<first, _rest::binary>> = binary} when first > 0 <- Base.decode64(value),
         true <- Base.encode64(binary) == value do
      {:ok, :binary.decode_unsigned(binary)}
    else
      _ -> {:error, :invalid_hop_state}
    end
  end

  defp parse_product(_duplicates), do: {:error, :invalid_hop_state}

  def response(:routing_loop) do
    "HTTP/1.1 418 I'm a teapot\r\nContent-Type: text/plain\r\n" <>
      "Content-Length: 12\r\nConnection: close\r\n\r\nI'm a teapot"
  end

  def response(:invalid_hop_state) do
    "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
  end

  def status(:routing_loop), do: 418
  def status(:invalid_hop_state), do: 400

  defp hop_header?(line) do
    line |> String.split(":", parts: 2) |> hd() |> String.downcase() == "x-hop-state"
  end
end
