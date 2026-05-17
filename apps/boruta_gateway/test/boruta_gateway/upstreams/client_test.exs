defmodule BorutaGateway.Upstreams.ClientTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias Boruta.Oauth.Token
  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Client
  alias BorutaGateway.Upstreams.ClientSupervisor
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  describe "ClientSupervisor.start_link/1" do
    test "application starts supervisor" do
      assert {:error, {:already_started, _pid}} = ClientSupervisor.start_link([])
    end
  end

  describe "ClientSupervisor.client_for_upstream/1" do
    setup do
      {:ok, upstream: %Upstream{id: SecureRandom.uuid()}}
    end

    test "starts a client", %{upstream: upstream} do
      {:ok, client} = ClientSupervisor.client_for_upstream(upstream)

      assert Process.alive?(client)
    end

    test "starts a client with an upstream", %{upstream: upstream} do
      {:ok, client} = ClientSupervisor.client_for_upstream(upstream)

      assert Client.upstream(client) == upstream
    end

    test "starts a client with a Finch instance", %{upstream: upstream} do
      {:ok, client} = ClientSupervisor.client_for_upstream(upstream)

      assert client |> Client.http_client() |> Process.whereis() |> Process.alive?()
    end
  end

  describe "build_request/2" do
    test "does not forward an empty signed token header without a signer" do
      request =
        %Upstream{scheme: "http", host: "example.test", port: 80}
        |> Client.build_request(conn_with_token())

      refute List.keymember?(request.headers, "x-forwarded-authorization", 0)
      assert {"authorization", "bearer token-value"} in request.headers
    end

    test "forwards a signed token header when a signer is configured" do
      request =
        %Upstream{
          scheme: "http",
          host: "example.test",
          port: 80,
          forwarded_token_signature_alg: "HS256",
          forwarded_token_secret: "secret"
        }
        |> Client.build_request(conn_with_token())

      assert {"x-forwarded-authorization", "bearer " <> jwt} =
               List.keyfind(request.headers, "x-forwarded-authorization", 0)

      assert {:ok, _claims} =
               Client.Token.verify(
                 jwt,
                 Joken.Signer.create("HS256", "secret")
               )
    end
  end

  # TODO change for an internal server
  describe "external http calls" do
    @tag :skip
    test "should request an external url (httpbin.patatoid.fr/status) given a Plug.Conn" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{scheme: "http", host: "httpbin.patatoid.fr", port: 80})

          :timer.sleep(100)

          conn = conn("GET", "/status/418")

          {:ok,
           %{
             body: body,
             status: status
           }} = Client.request(Upstream.with_http_client(upstream), conn)

          assert status == 418
          assert body =~ ~r/teapot/
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    @tag :skip
    test "should request an external url (httpbin.patatoid.fr/headers) given a Plug.Conn" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{scheme: "http", host: "httpbin.patatoid.fr", port: 80})

          :timer.sleep(100)

          conn =
            conn("GET", "/headers")
            |> put_req_header("authorization", "Bearer test")

          {:ok,
           %{
             body: body,
             status: status
           }} = Client.request(Upstream.with_http_client(upstream), conn)

          assert status == 200

          req_headers = Jason.decode!(body)["headers"]

          assert Enum.any?(req_headers, fn
                   {"Authorization", "Bearer test"} -> true
                   _ -> false
                 end)

          assert Enum.any?(req_headers, fn
                   {"Host", "httpbin.patatoid.fr"} -> true
                   _ -> false
                 end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end

  defp conn_with_token do
    "GET"
    |> conn("/resource")
    |> assign(:token, %Token{type: "access_token", value: "token-value"})
  end
end
