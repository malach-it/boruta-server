defmodule BorutaGateway.NoiseCancellingTest do
  use ExUnit.Case, async: false

  alias BorutaGateway.NoiseCancelling
  alias BorutaGateway.PhiNoise
  alias BorutaGateway.Upstreams.Upstream

  @openapi Jason.encode!(%{
             "openapi" => "3.0.0",
             "paths" => %{
               "/widgets/{id}" => %{"get" => %{}}
             }
           })

  setup do
    if :ets.whereis(NoiseCancelling) != :undefined do
      :ets.delete_all_objects(NoiseCancelling)
    end

    :ok
  end

  test "allows documented requests and rejects noise using the stored model" do
    {:ok, model} = PhiNoise.train(@openapi)

    upstream = %Upstream{
      id: Ecto.UUID.generate(),
      noise_cancelling_enabled: true,
      noise_cancelling_model: PhiNoise.export(model),
      strip_uri: false
    }

    assert :ok = NoiseCancelling.check(upstream, "GET", "/widgets/123", {127, 0, 0, 1})
    assert :ok = NoiseCancelling.check(upstream, "GET", "/widgets/456", {127, 0, 0, 1})

    assert {:noise, %{noise: true, openapi_match: false}} =
             NoiseCancelling.check(upstream, "GET", "/.env", {127, 0, 0, 2})
  end

  test "evaluates the path forwarded to an upstream when its URI is stripped" do
    {:ok, model} = PhiNoise.train(@openapi)

    upstream = %Upstream{
      id: Ecto.UUID.generate(),
      uris: ["/api"],
      strip_uri: true,
      noise_cancelling_enabled: true,
      noise_cancelling_model: PhiNoise.export(model)
    }

    assert :ok = NoiseCancelling.check(upstream, "GET", "/api", "root-client")
    assert :ok = NoiseCancelling.check(upstream, "GET", "/api/widgets/123", "client")
  end

  test "allows context to classify a documented request as noise only after an illegal move" do
    {:ok, model} = PhiNoise.train(@openapi)

    upstream = %Upstream{
      id: Ecto.UUID.generate(),
      noise_cancelling_enabled: true,
      noise_cancelling_model: PhiNoise.export(model),
      strip_uri: false
    }

    assert {:noise, %{openapi_match: false}} =
             NoiseCancelling.check(upstream, "GET", "/.env", "client")

    assert {:noise, %{openapi_match: true}} =
             NoiseCancelling.check(upstream, "GET", "/widgets/123", "client")
  end

  test "does nothing when noise cancelling is disabled" do
    upstream = %Upstream{noise_cancelling_enabled: false}
    assert :ok = NoiseCancelling.check(upstream, "GET", "/.env", "client")
  end
end
