defmodule BorutaGateway.Upstreams.Store do
  @moduledoc false

  use GenServer

  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams.Upstream

  def start_link do
    upstreams = Repo.all(Upstream)

    with {:ok, _listener} <- GenServer.start_link(__MODULE__, []) do
      Agent.start_link(fn -> structure(upstreams) end, name: __MODULE__)
    end
  end

  @spec match(path_info :: list(String.t())) :: upstream :: Upstream.t() | nil
  def match(path_info) do
    Agent.get(__MODULE__, fn (upstreams) ->
      with {_prefix_info, upstream} <- Enum.find(upstreams, fn ({prefix_info, _upstream}) ->
        path_info = Enum.take(path_info, length(prefix_info))

        Enum.empty?(prefix_info -- path_info)
      end) do
        upstream
      end
    end)
  end

  @impl GenServer
  def init(opts) do
    case Repo.listen("upstreams_changed") do
      {:ok, _pid, _ref} -> {:ok, opts}
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, "upstreams_changed", payload}, state) do
    handle_notification(Jason.decode!(payload))

    {:noreply, state}
  end

  defp handle_notification(%{"operation" => "INSERT", "record" => record}) do
    new = struct(
      Upstream,
      Enum.map(record, fn ({key, value}) -> {String.to_atom(key), value} end)
    )
    Agent.update(__MODULE__, fn (upstreams) ->
      upstreams
      |> Enum.map(fn ({_uri, upstream}) -> upstream end)
      |> List.insert_at(0, new)
      |> structure()
    end)
  end
  defp handle_notification(%{"operation" => "UPDATE", "record" => record}) do
    updated = struct(
      Upstream,
      Enum.map(record, fn ({key, value}) -> {String.to_atom(key), value} end)
    )
    updated_id = updated.id

    Agent.update(__MODULE__, fn (upstreams) ->
      upstreams
      |> Enum.map(fn ({_uri, upstream}) -> upstream end)
      |> Enum.map(fn
        (%{id: ^updated_id}) -> updated
        (upstream) -> upstream
      end)
      |> structure()
    end)
  end
  defp handle_notification(%{"operation" => "DELETE", "record" => %{"id" => id}}) do
    Agent.update(__MODULE__, fn (upstreams) ->
      upstreams
      |> Enum.map(fn ({_uri, upstream}) -> upstream end)
      |> Enum.reject(fn
        (%{id: ^id}) -> true
        (_) -> false
      end)
      |> structure()
    end)
  end

  defp structure(upstreams) do
    Enum.reduce(upstreams, [], fn (upstream, acc) ->
      (acc ++
        Enum.map(upstream.uris, fn (prefix) ->
          prefix_info = String.split(prefix, "/", trim: true)

          {prefix_info, upstream}
        end))
      |> Enum.sort_by(fn ({path_info, _upstream}) -> length(path_info) end, :desc)
    end)
  end
end
