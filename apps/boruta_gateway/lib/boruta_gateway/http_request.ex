defmodule BorutaGateway.HttpRequest do
  @moduledoc false

  @header_separator "\r\n\r\n"

  @type parsed :: %{
          header: binary(),
          header_payload: binary(),
          body: binary(),
          payload: binary(),
          body_remaining: non_neg_integer()
        }

  @spec parse(binary(), pos_integer()) ::
          {:ok, parsed()} | {:more, binary()} | {:error, atom()}
  def parse(payload, max_header_bytes) when is_binary(payload) and max_header_bytes > 0 do
    case :binary.match(payload, @header_separator) do
      :nomatch when byte_size(payload) > max_header_bytes ->
        {:error, :headers_too_large}

      :nomatch ->
        {:more, payload}

      {header_length, _separator_length} when header_length > max_header_bytes ->
        {:error, :headers_too_large}

      {header_length, separator_length} ->
        header = binary_part(payload, 0, header_length)
        body_offset = header_length + separator_length
        body = binary_part(payload, body_offset, byte_size(payload) - body_offset)

        with true <- String.valid?(header),
             {:ok, headers} <- parse_headers(header),
             :ok <- validate_transfer_encoding(headers),
             {:ok, content_length} <- content_length(headers),
             true <- byte_size(body) <= content_length do
          {:ok,
           %{
             header: header,
             header_payload: binary_part(payload, 0, body_offset),
             body: body,
             payload: payload,
             body_remaining: content_length - byte_size(body)
           }}
        else
          false -> {:error, :invalid_request}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec consume_body(binary(), non_neg_integer()) ::
          {:ok, binary(), non_neg_integer()} | {:error, :body_too_large}
  def consume_body(payload, remaining) when byte_size(payload) <= remaining do
    {:ok, payload, remaining - byte_size(payload)}
  end

  def consume_body(_payload, _remaining), do: {:error, :body_too_large}

  defp parse_headers(header) do
    header
    |> String.split("\r\n")
    |> Enum.drop(1)
    |> Enum.reduce_while({:ok, %{}}, fn line, {:ok, headers} ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          name = String.downcase(name)

          if valid_header_name?(name) && valid_header_value?(value) do
            {:cont,
             {:ok, Map.update(headers, name, [String.trim(value)], &[String.trim(value) | &1])}}
          else
            {:halt, {:error, :invalid_header}}
          end

        _ ->
          {:halt, {:error, :invalid_header}}
      end
    end)
  end

  defp valid_header_name?(name) do
    name != "" && String.match?(name, ~r/^[!#$%&'*+.^_`|~0-9a-z-]+$/)
  end

  defp valid_header_value?(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> byte == 9 || (byte >= 32 && byte != 127) end)
  end

  defp validate_transfer_encoding(%{"transfer-encoding" => _values}),
    do: {:error, :unsupported_transfer_encoding}

  defp validate_transfer_encoding(_headers), do: :ok

  defp content_length(headers) do
    case Map.get(headers, "content-length", []) do
      [] ->
        {:ok, 0}

      [value] ->
        case Integer.parse(value) do
          {length, ""} when length >= 0 -> {:ok, length}
          _invalid -> {:error, :invalid_content_length}
        end

      _duplicates ->
        {:error, :multiple_content_lengths}
    end
  end
end
