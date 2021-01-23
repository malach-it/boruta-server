defmodule BorutaWeb.Metrics do
  @moduledoc false

  defmodule Measurements do
    @moduledoc false

    defstruct start_time: nil,
              request_time: nil,
              gateway_time: nil,
              upstream_time: nil,
              status_code: nil

    @type t :: %{
            start_time: integer(),
            request_time: integer(),
            gateway_time: integer(),
            upstream_time: integer(),
            statuc_code: integer()
          }
  end

  use GenServer

  alias BorutaWeb.Metrics.Measurements
  alias BorutaWeb.Metrics.Producer
  alias BorutaWeb.MetricsChannel

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    # TODO kill producer on shutdown
    {:ok, _producer} = Producer.start_link([])
    GenServer.cast(__MODULE__, :subscribe)

    {:ok, []}
  end

  @impl GenServer
  def handle_cast(:subscribe, state) do
    :telemetry.attach(
      'boruta_gateway:channel',
      [:boruta_gateway, :request, :done],
      &handle_event/4,
      nil
    )

    Flow.from_enumerables([Producer.stream()],
      max_demand: 1,
      min_demand: 0,
      stages: 1,
      window: Flow.Window.global() |> Flow.Window.trigger_periodically(1000, :millisecond)
    )
    |> Flow.reduce(
      fn ->
        %{
          start_times: 0,
          request_times: [],
          gateway_times: [],
          upstream_times: [],
          count: 0
        }
      end,
      &aggregate/2
    )
    |> Flow.on_trigger(fn
      %{count: 0} = measurements ->
        {[], measurements}

      %{
        start_time: start_time,
        request_times: request_times,
        gateway_times: gateway_times,
        upstream_times: upstream_times,
        status_code: status_code,
        count: count
      } = measurements ->
        MetricsChannel.handle_event(%{
          start_time: start_time / 1000,
          request_time: Enum.sum(request_times) / count,
          gateway_time: Enum.sum(gateway_times) / count,
          upstream_time: Enum.sum(upstream_times) / count,
          status_code: status_code,
          count: count
        })

        {[measurements], %{count: 0}}
    end)
    |> Flow.run()

    {:noreply, state}
  end

  @spec aggregate(
          measurement :: atom() | Measurements.t(),
          acc :: %{
            start_time: integer(),
            request_times: list(integer()),
            gateway_times: list(integer()),
            upstream_times: list(integer()),
            count: integer()
          }
        ) :: %{
          start_time: integer(),
          request_times: list(integer()),
          gateway_times: list(integer()),
          upstream_times: list(integer()),
          status_code: integer(),
          count: integer()
        }
  defp aggregate(%Measurements{} = measurement, acc) do
    %{
      start_time: measurement.start_time,
      request_times: [measurement.request_time | acc[:request_times] || []],
      gateway_times: [measurement.gateway_time | acc[:gateway_times] || []],
      upstream_times: [measurement.upstream_time | acc[:upstream_times] || []],
      count: acc[:count] + 1,
      status_code: measurement.status_code
    }
  end

  defp aggregate(_, acc), do: acc

  def handle_event(
        [:boruta_gateway, :request, :done],
        %{
          request_time: request_time,
          gateway_time: gateway_time,
          upstream_time: upstream_time,
          status_code: status_code
        },
        %{start_time: start_time},
        _state
      ) do
    Producer.increment(%Measurements{
      start_time: start_time,
      request_time: request_time,
      gateway_time: gateway_time,
      upstream_time: upstream_time,
      status_code: status_code
    })
  end

  defmodule Producer do
    @moduledoc false

    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: __MODULE__)
    end

    def init(_args), do: {:ok, []}

    def handle_call(:demand, _from, state) do
      {:reply, state, []}
    end

    def handle_call({:increment, measurement}, _from, state) do
      new_state = [measurement | state]
      {:reply, :ok, new_state}
    end

    @spec increment(measurements :: %Measurements{}) :: :ok
    def increment(
          %Measurements{
            start_time: start_time,
            request_time: request_time,
            gateway_time: gateway_time,
            upstream_time: upstream_time
          } = measurement
        )
        when is_integer(start_time) and
               is_integer(request_time) and
               is_integer(gateway_time) and
               is_integer(upstream_time) do
      GenServer.call(__MODULE__, {:increment, measurement})
    end

    def increment(e) do
      {:error, "#{inspect(e)} is invalid measurements."}
    end

    def demand do
      GenServer.call(__MODULE__, :demand)
    end

    def stream do
      Stream.resource(
        fn -> start_link([]) end,
        fn pid ->
          :timer.sleep(100)
          {demand(), pid}
        end,
        fn _pid -> nil end
      )
    end
  end
end
