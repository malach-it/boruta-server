defmodule BorutaGateway.NoiseCancelling do
  @moduledoc false

  use GenServer

  alias BorutaGateway.PhiNoise
  alias BorutaGateway.Upstreams.Upstream

  @table __MODULE__
  @memory_limit 32
  @valid_context_weight 1.0
  @cancelled_context_weight 0.95
  @forbidden_body "the request has been rejected by the server"

  @unmatched_prediction %{
    in_scope: false,
    openapi_match: false,
    noise: true,
    score: 0.0,
    noise_score: 1.0,
    reason: :unmatched_upstream
  }

  def start_link(_options) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def check(%Upstream{noise_cancelling_enabled: false}, _method, _path, _client), do: :ok
  def check(%Upstream{noise_cancelling_model: nil}, _method, _path, _client), do: :ok

  def check(%Upstream{} = upstream, method, path, client) do
    request = %{method: method, path: upstream_path(upstream, path)}
    memory_key = {:memory, upstream.id, client}
    history = lookup(memory_key, [])
    prediction = PhiNoise.predict(model(upstream), request, history)

    context_weight =
      if prediction.noise, do: @cancelled_context_weight, else: @valid_context_weight

    request = Map.put(request, :context_weight, context_weight)
    history = Enum.take(history ++ [request], -@memory_limit)
    :ets.insert(@table, {memory_key, history})

    if prediction.noise, do: {:noise, prediction}, else: :ok
  rescue
    _error -> :ok
  end

  @spec forbidden_response() :: binary()
  def forbidden_response do
    "HTTP/1.1 403 Forbidden\r\n" <>
      "Content-Type: text/plain; charset=utf-8\r\n" <>
      "Content-Length: #{byte_size(@forbidden_body)}\r\n\r\n" <>
      @forbidden_body
  end

  @spec unmatched_prediction() :: map()
  def unmatched_prediction, do: @unmatched_prediction

  @impl GenServer
  def init(_options) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end

  defp model(%Upstream{id: id, noise_cancelling_model: serialized}) do
    key = {:model, id}

    case :ets.lookup(@table, key) do
      [{^key, ^serialized, model}] ->
        model

      _ ->
        {:ok, model} = PhiNoise.load(serialized)
        :ets.insert(@table, {key, serialized, model})
        model
    end
  end

  defp lookup(key, default) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> default
    end
  end

  defp upstream_path(%Upstream{strip_uri: false}, path), do: path

  defp upstream_path(%Upstream{uris: uris}, path) do
    uri =
      uris
      |> Enum.sort_by(&byte_size/1, :desc)
      |> Enum.find("/", &uri_matches?(&1, path))

    path
    |> String.replace_prefix(uri, "")
    |> normalize_path()
  end

  defp uri_matches?("/", _path), do: true
  defp uri_matches?(uri, path), do: path == uri || String.starts_with?(path, uri <> "/")

  defp normalize_path(""), do: "/"
  defp normalize_path("?" <> query), do: "/?" <> query
  defp normalize_path(path), do: path
end
