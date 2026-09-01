defmodule BorutaAdmin.Yaml do
  @moduledoc false

  @spec encode(term()) :: String.t()
  def encode(value) do
    "---\n" <> encode_node(value, 0)
  end

  defp encode_node(%{} = map, level) when map_size(map) == 0 do
    indent(level) <> "{}\n"
  end

  defp encode_node(%{} = map, level) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join(fn {key, value} ->
      prefix = indent(level) <> scalar(to_string(key)) <> ":"

      if collection?(value) do
        prefix <> "\n" <> encode_node(value, level + 1)
      else
        prefix <> " " <> scalar(value) <> "\n"
      end
    end)
  end

  defp encode_node([], level), do: indent(level) <> "[]\n"

  defp encode_node(list, level) when is_list(list) do
    Enum.map_join(list, fn value ->
      prefix = indent(level) <> "-"

      if collection?(value) do
        prefix <> "\n" <> encode_node(value, level + 1)
      else
        prefix <> " " <> scalar(value) <> "\n"
      end
    end)
  end

  defp encode_node(value, level), do: indent(level) <> scalar(value) <> "\n"

  defp collection?(%{}), do: true
  defp collection?(value) when is_list(value), do: true
  defp collection?(_value), do: false

  defp scalar(value) when is_binary(value), do: Jason.encode!(value)
  defp scalar(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp scalar(true), do: "true"
  defp scalar(false), do: "false"
  defp scalar(nil), do: "null"

  defp indent(level), do: String.duplicate("  ", level)
end
