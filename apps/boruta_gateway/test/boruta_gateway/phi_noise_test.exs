defmodule BorutaGateway.PhiNoiseTest do
  use ExUnit.Case, async: true

  alias BorutaGateway.PhiNoise

  @root_methods ~w(GET POST PUT PATCH DELETE HEAD OPTIONS TRACE)
  @any_root_methods @root_methods ++ ~w(CONNECT PURGE)

  @openapi Jason.encode!(%{
             "openapi" => "3.0.0",
             "paths" => %{
               "/api/clients" => %{"get" => %{}, "post" => %{}},
               "/api/clients/{client_id}" => %{"get" => %{}}
             }
           })

  test "trains noise labels exclusively from OpenAPI operations" do
    assert {:ok, model} = PhiNoise.train(@openapi, epochs: 2_000, epsilon: 0.01)
    assert model.stats.synthetic_examples > 0
    assert model.stats.openapi_operations == 12
    assert model.stats.graph_nodes == 12
    assert model.stats.graph_path_nodes == 3
    assert model.stats.graph_method_nodes == 9
    assert model.stats.request_contexts == 12
    assert model.stats.request_context_relationships == 132
    assert model.stats.request_context_weight == 0.6
    assert model.stats.phi_max_degree == 2
    assert model.stats.max_error <= 0.01

    assert model.stats.examples == model.stats.synthetic_examples

    signal =
      PhiNoise.predict(model, %{
        method: "GET",
        path: "/api/clients/another-client"
      })

    noise =
      PhiNoise.predict(model, %{
        method: "GET",
        path: "/api/config.php"
      })

    assert signal.in_scope
    assert signal.openapi_match
    refute signal.noise
    assert signal.score > 0.5
    assert signal.noise_score < 0.5
    assert_in_delta signal.score + signal.noise_score, 1.0, 1.0e-12

    assert noise.in_scope
    refute noise.openapi_match
    assert noise.noise
    assert noise.score <= 0.5
    assert noise.noise_score >= 0.5
    assert_in_delta noise.score + noise.noise_score, 1.0, 1.0e-12
  end

  test "learns all OpenAPI operations" do
    assert {:ok, model} = PhiNoise.train(@openapi, epochs: 2_000, epsilon: 0.01)
    assert model.stats.synthetic_examples > 0

    signal =
      PhiNoise.predict(model, %{
        method: "GET",
        path: "/api/clients/previously-unseen-id"
      })

    wrong_method =
      PhiNoise.predict(model, %{
        method: "CONNECT",
        path: "/api/clients/previously-unseen-id"
      })

    refute signal.noise
    assert signal.openapi_match
    assert wrong_method.noise
    refute wrong_method.openapi_match
  end

  test "labels unspecified method-path relationships in the complete graph as noise" do
    assert {:ok, model} = PhiNoise.train(@openapi, epochs: 2_000, epsilon: 0.01)

    prediction =
      PhiNoise.predict(model, %{
        method: "POST",
        path: "/api/clients/previously-unseen-id"
      })

    refute prediction.openapi_match
    assert prediction.noise
  end

  test "uses every other OpenAPI request as lower-weight request context" do
    assert {:ok, model} = PhiNoise.train(@openapi)
    exported = model |> PhiNoise.export() |> Jason.decode!()

    graph_nodes = MapSet.new(exported["graph_nodes"])
    assert MapSet.size(graph_nodes) == 12
    assert "path:/" in graph_nodes
    assert "path:/api/clients" in graph_nodes
    assert "path:/api/clients/{}" in graph_nodes
    assert Enum.all?(@root_methods, fn method -> "method:#{method}" in graph_nodes end)
    assert "method:*" in graph_nodes

    legal_requests =
      MapSet.new([
        "GET /api/clients",
        "GET /api/clients/{}",
        "POST /api/clients"
      ])

    openapi_requests = MapSet.new(exported["openapi_requests"])
    assert MapSet.subset?(legal_requests, openapi_requests)
    assert Enum.all?(@root_methods, &("#{&1} /" in openapi_requests))
    assert "* /" in openapi_requests
    assert exported["request_context_weight"] == 0.6

    request_terms =
      exported["weights"]
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "phi:request:"))

    assert "phi:request:GET /api/clients" in request_terms
    assert "phi:request:GET /api/clients/{}" in request_terms
    assert "phi:request:POST /api/clients" in request_terms

    assert Map.has_key?(
             exported["weights"],
             "phi:degree2:GET /api/clients*POST /api/clients"
           )

    refute Enum.any?(Map.keys(exported["weights"]), &String.contains?(&1, "method:GET->path:"))
  end

  test "treats the root path as a valid move for every method" do
    assert {:ok, model} = PhiNoise.train(@openapi)

    for method <- @any_root_methods, path <- ["", "/"] do
      prediction = PhiNoise.predict(model, %{method: method, path: path})

      assert prediction.in_scope
      assert prediction.openapi_match
      refute prediction.noise
      assert prediction.score > 0.5
    end
  end

  test "keeps a documented operation as signal" do
    assert {:ok, model} = PhiNoise.train(@openapi)

    prediction =
      PhiNoise.predict(model, %{
        method: "GET",
        path: "/api/clients/client-id"
      })

    assert prediction.openapi_match
    refute prediction.noise
  end

  test "exports and reloads a trained model" do
    assert {:ok, model} = PhiNoise.train(@openapi)
    serialized = PhiNoise.export(model)
    assert {:ok, loaded} = PhiNoise.load(serialized)

    request = %{method: "GET", path: "/api/.git/config"}
    assert PhiNoise.predict(loaded, request) == PhiNoise.predict(model, request)
  end

  test "uses a bounded recent-request memory as prediction context" do
    assert {:ok, model} = PhiNoise.train(@openapi)

    memory =
      for index <- 1..40 do
        %{method: "GET", path: "/api/clients/#{index}"}
      end

    prediction =
      PhiNoise.predict(
        model,
        %{method: "GET", path: "/test"},
        memory
      )

    assert prediction.memory_size == 32
    assert prediction.noise
  end

  test "can classify a legal request as contextual noise after illegal moves" do
    assert {:ok, model} = PhiNoise.train(@openapi)

    illegal_memory =
      for index <- 1..32 do
        %{method: "GET", path: "/scanner/#{index}"}
      end

    prediction =
      PhiNoise.predict(
        model,
        %{method: "GET", path: "/api/clients"},
        illegal_memory
      )

    assert prediction.openapi_match
    assert prediction.noise
    assert prediction.memory_size == 32
  end

  test "classifies unmatched gateway paths as noise" do
    assert {:ok, model} = PhiNoise.train(@openapi)

    for request <- [
          %{method: "GET", path: "/test"},
          %{method: "POST", path: "/oauth/token"}
        ] do
      prediction = PhiNoise.predict(model, request)

      assert prediction.in_scope
      refute prediction.openapi_match
      assert prediction.noise
      assert prediction.score < 0.5
      assert prediction.noise_score >= 0.5
    end
  end
end
