defmodule BorutaGateway.ForwardedHeaders do
  @moduledoc false

  def put_basic(payload, remote_ip, scheme) when scheme in [:http, :https] do
    [header, body] = String.split(payload, "\r\n\r\n", parts: 2)
    [request_line | headers] = String.split(header, "\r\n")

    authorization = authenticated_value(headers)

    host = header_value(headers, "host")

    forwarded =
      ["for=" <> forwarded_ip(remote_ip), "proto=" <> Atom.to_string(scheme)] ++
        if(host, do: ["host=" <> quoted(host)], else: [])

    headers =
      Enum.reject(headers, fn line ->
        header_name(line) in ["authorization", "x-forwarded-authorization", "forwarded"]
      end)

    Enum.join(
      [request_line | headers] ++
        [
          "Forwarded: " <> Enum.join(forwarded, ";"),
          "X-Forwarded-Authorization: " <> authorization
        ],
      "\r\n"
    ) <> "\r\n\r\n" <> body
  end

  defp authenticated_value(headers) do
    Enum.find_value(headers, fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          if String.downcase(key) == "authorization" &&
               String.match?(String.trim(value), ~r/\Abasic[\t ]+/i),
             do: String.trim(value)

        _ ->
          nil
      end
    end)
  end

  defp header_value(headers, name) do
    Enum.find_value(headers, fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> if String.downcase(key) == name, do: String.trim(value)
        _ -> nil
      end
    end)
  end

  defp header_name(line), do: line |> String.split(":", parts: 2) |> hd() |> String.downcase()

  defp forwarded_ip(:unknown), do: "unknown"

  defp forwarded_ip(address) do
    address = to_string(address)
    if String.contains?(address, ":"), do: quoted("[" <> address <> "]"), else: address
  end

  defp quoted(value) do
    "\"" <> (value |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")) <> "\""
  end
end
