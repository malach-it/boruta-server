defmodule BorutaGateway.PhiNoise do
  @moduledoc """
  Trains and applies a native Phi classifier for gateway request-path noise.

  Training is derived exclusively from the OpenAPI document. A method/path is
  signal when it matches an operation and noise otherwise. Each method and
  path template is a node. Each OpenAPI operation is a request context related
  to every other documented request at a lower weight; there is no direct
  method-to-path relationship. Whole requests are additive Phi examples:
  `phi(a + 0.6b + 0.6c) = phi(a) + 0.6phi(b) + 0.6phi(c)`. Prediction `score`
  is legal-match confidence; `noise_score` is its complement, and `phi_value`
  exposes the raw additive noise value before bounding. Sparse degree-two
  terms `phi(ab)`, `phi(ac)`, and so on learn primary-request relationships.
  Prediction accepts up to 32 recent requests as recency-decayed context.
  """

  alias __MODULE__.{Model, Native}

  @memory_limit 32

  defmodule Model do
    @moduledoc false
    @enforce_keys [:resource, :stats]
    defstruct [:resource, :stats]

    @type t :: %__MODULE__{resource: term(), stats: map() | nil}
  end

  @type request :: %{
          required(:method) => String.t(),
          required(:path) => String.t()
        }

  @spec train(String.t(), keyword()) :: {:ok, Model.t()}
  def train(openapi_json, options \\ []) when is_binary(openapi_json) and is_list(options) do
    epochs = Keyword.get(options, :epochs, 1_000)
    epsilon = Keyword.get(options, :epsilon, 0.02)
    {resource, stats} = Native.train(openapi_json, epochs, epsilon)

    {:ok, %Model{resource: resource, stats: stats}}
  end

  @spec predict(Model.t(), request()) :: map()
  @spec predict(Model.t(), request(), [request()]) :: map()
  def predict(%Model{resource: resource}, request, memory \\ []) when is_list(memory) do
    memory = memory |> Enum.take(-@memory_limit) |> Enum.map(&normalize_request/1)
    Native.predict(resource, normalize_request(request), memory)
  end

  @spec export(Model.t()) :: String.t()
  def export(%Model{resource: resource}), do: Native.export_model(resource)

  @spec load(String.t()) :: {:ok, Model.t()}
  def load(serialized) when is_binary(serialized) do
    {:ok, %Model{resource: Native.load_model(serialized), stats: nil}}
  end

  defp normalize_request(request) do
    %{
      method: request |> fetch!(:method) |> to_string(),
      path: request |> fetch!(:path) |> to_string()
    }
  end

  defp fetch!(map, key),
    do: Map.get_lazy(map, key, fn -> Map.fetch!(map, Atom.to_string(key)) end)
end

defmodule BorutaGateway.PhiNoise.Native do
  @moduledoc false

  use Rustler, otp_app: :boruta_gateway, crate: "phi_noise_nif"

  def train(_openapi_json, _epochs, _epsilon), do: :erlang.nif_error(:nif_not_loaded)
  def predict(_model, _request, _memory), do: :erlang.nif_error(:nif_not_loaded)
  def export_model(_model), do: :erlang.nif_error(:nif_not_loaded)
  def load_model(_serialized), do: :erlang.nif_error(:nif_not_loaded)
end
