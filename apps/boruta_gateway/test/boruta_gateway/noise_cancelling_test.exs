defmodule BorutaGateway.NoiseCancellingTest do
  use ExUnit.Case, async: false

  alias BorutaGateway.NoiseCancelling
  alias BorutaGateway.PhiNoise
  alias BorutaGateway.Upstreams.Upstream

  test "classifies an unmatched request as deterministic noise" do
    assert %{
             in_scope: false,
             openapi_match: false,
             noise: true,
             reason: :unmatched_upstream
           } = prediction = NoiseCancelling.unmatched_prediction()

    assert prediction.score == 0.0
    assert prediction.noise_score == 1.0
  end

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

  test "builds a 403 Forbidden response for cancelled requests" do
    assert NoiseCancelling.forbidden_response() ==
             "HTTP/1.1 403 Forbidden\r\n" <>
               "Content-Type: text/plain; charset=utf-8\r\n" <>
               "Content-Length: 43\r\n\r\n" <>
               "the request has been rejected by the server"
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

  test "allows context to classify a documented request as noise after an illegal move" do
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

  test "gives valid requests more context weight than cancelled requests" do
    {:ok, model} = PhiNoise.train(@openapi)
    upstream_id = Ecto.UUID.generate()

    upstream = %Upstream{
      id: upstream_id,
      noise_cancelling_enabled: true,
      noise_cancelling_model: PhiNoise.export(model),
      strip_uri: false
    }

    assert :ok = NoiseCancelling.check(upstream, "GET", "/widgets/123", "valid-client")
    assert {:noise, _prediction} = NoiseCancelling.check(upstream, "GET", "/.env", "noise-client")

    assert [{{:memory, ^upstream_id, "valid-client"}, [%{context_weight: 1.0}]}] =
             :ets.lookup(NoiseCancelling, {:memory, upstream_id, "valid-client"})

    assert [{{:memory, ^upstream_id, "noise-client"}, [%{context_weight: 0.95}]}] =
             :ets.lookup(NoiseCancelling, {:memory, upstream_id, "noise-client"})
  end
end
