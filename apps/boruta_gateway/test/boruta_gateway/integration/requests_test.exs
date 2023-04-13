defmodule BorutaGateway.RequestsIntegrationTest do
  use ExUnit.Case
  use Plug.Test
  use BorutaGateway.DataCase

  alias Boruta.AccessTokensAdapter
  alias Boruta.ClientsAdapter
  alias BorutaGateway.Repo
  alias BorutaGateway.RequestsIntegrationTest.HttpClient
  alias BorutaGateway.Upstreams
  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  setup_all do
    Finch.start_link(name: HttpClient)

    :ok
  end

  describe "requests" do
    setup do
      {:ok, %Boruta.Ecto.Client{id: client_id}} = Boruta.Ecto.Admin.create_client(%{})

      {:ok, access_token} =
        AccessTokensAdapter.create(
          %{
            client: ClientsAdapter.get_client(client_id),
            scope: "test"
          },
          []
        )

      {:ok, access_token: access_token}
    end

    test "returns a 404 when no upstream found" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          Upstreams.create_upstream(%{
            scheme: "http",
            host: "should.not.be.called",
            port: 80,
            uris: ["/upstream"]
          })

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7777/no_upstream", [], "")

          assert {:ok, %Finch.Response{body: body, status: 404}} =
                   Finch.request(request, HttpClient)

          assert body == "No upstream has been found corresponding to the given request."
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns a 401 when unauthorized" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "should.not.be.called",
              port: 80,
              uris: ["/unauthorized"],
              authorize: true,
              error_content_type: "text",
              unauthorized_response: "boom"
            })

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7777/unauthorized", [], "")

          assert {:ok, %Finch.Response{body: body, headers: headers, status: 401}} =
                   Finch.request(request, HttpClient)

          assert body == upstream.unauthorized_response

          assert Enum.any?(headers, fn
                   {"content-type", content_type} ->
                     upstream.error_content_type
                     |> Regex.compile!()
                     |> Regex.match?(content_type)

                   _ ->
                     false
                 end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns a 403 when forbidden", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "should.not.be.called",
              port: 80,
              uris: ["/forbidden"],
              authorize: true,
              required_scopes: %{"GET" => ["required"]},
              error_content_type: "text",
              forbidden_response: "boom"
            })

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/forbidden",
              [{"authorization", "Bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, headers: headers, status: 403}} =
                   Finch.request(request, HttpClient)

          assert body == upstream.forbidden_response

          assert Enum.any?(headers, fn
                   {"content-type", content_type} ->
                     upstream.error_content_type
                     |> Regex.compile!()
                     |> Regex.match?(content_type)

                   _ ->
                     false
                 end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns response when authorized", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          Upstreams.create_upstream(%{
            scheme: "http",
            host: "httpbin.patatoid.fr",
            port: 80,
            uris: ["/httpbin"],
            strip_uri: true,
            authorize: true,
            required_scopes: %{"GET" => ["test"]}
          })

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/httpbin/status/418",
              [{"authorization", "Bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, status: 418}} =
                   Finch.request(request, HttpClient)

          assert body =~ ~r/teapot/
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns authorization header with introspected token when authorized", %{
      access_token: access_token
    } do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "httpbin.patatoid.fr",
              port: 80,
              uris: ["/httpbin"],
              strip_uri: true,
              authorize: true,
              required_scopes: %{"GET" => ["test"]},
              forwarded_token_signature_alg: "HS256"
            })

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/httpbin/anything",
              [{"authorization", "bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, status: 200}} =
                   Finch.request(request, HttpClient)

          assert %{
                   "headers" => %{
                     "Authorization" => authorization,
                     "X-Forwarded-Authorization" => forwarded_authorization
                   }
                 } = Jason.decode!(body)

          assert [_authorization_header, token] = Regex.run(~r/bearer (.+)/, authorization)
          signer = Upstreams.Client.signer(upstream)
          assert {:ok, claims} = Upstreams.Client.Token.verify(token, signer)
          assert claims["client_id"] == access_token.client.id
          assert claims["value"] == access_token.value

          assert forwarded_authorization == "bearer #{access_token.value}"
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end

  describe "requests (from configuration file)" do
    setup do
      {:ok, %Boruta.Ecto.Client{id: client_id}} = Boruta.Ecto.Admin.create_client(%{})

      {:ok, access_token} =
        AccessTokensAdapter.create(
          %{
            client: ClientsAdapter.get_client(client_id),
            scope: "test"
          },
          []
        )

      {:ok, access_token: access_token}
    end

    test "returns a 404 when no upstream found" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          configuration_file_path =
            :code.priv_dir(:boruta_gateway)
            |> Path.join("/test/configuration_files/not_found.yml")

          ConfigurationLoader.from_file!(configuration_file_path)

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7777/no_upstream", [], "")

          assert {:ok, %Finch.Response{body: body, status: 404}} =
                   Finch.request(request, HttpClient)

          assert body == "No upstream has been found corresponding to the given request."
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns a 401 when unauthorized" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          configuration_file_path =
            :code.priv_dir(:boruta_gateway)
            |> Path.join("/test/configuration_files/unauthorized.yml")

          ConfigurationLoader.from_file!(configuration_file_path)

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7777/unauthorized", [], "")

          assert {:ok, %Finch.Response{body: body, headers: headers, status: 401}} =
                   Finch.request(request, HttpClient)

          assert body == "boom"

          assert Enum.any?(headers, fn
                   {"content-type", content_type} ->
                     Regex.match?(~r/text/, content_type)

                   _ ->
                     false
                 end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns a 403 when forbidden", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          configuration_file_path =
            :code.priv_dir(:boruta_gateway)
            |> Path.join("/test/configuration_files/forbidden.yml")

          ConfigurationLoader.from_file!(configuration_file_path)

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/forbidden",
              [{"authorization", "Bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, headers: headers, status: 403}} =
                   Finch.request(request, HttpClient)

          assert body == "boom"

          assert Enum.any?(headers, fn
                   {"content-type", content_type} ->
                     Regex.match?(~r/text/, content_type)

                   _ ->
                     false
                 end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns response when authorized", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          configuration_file_path =
            :code.priv_dir(:boruta_gateway)
            |> Path.join("/test/configuration_files/authorized.yml")

          ConfigurationLoader.from_file!(configuration_file_path)

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/httpbin/status/418",
              [{"authorization", "Bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, status: 418}} =
                   Finch.request(request, HttpClient)

          assert body =~ ~r/teapot/
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns authorization header with introspected token when authorized", %{
      access_token: access_token
    } do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          configuration_file_path =
            :code.priv_dir(:boruta_gateway)
            |> Path.join("/test/configuration_files/authorized_introspect.yml")

          ConfigurationLoader.from_file!(configuration_file_path)

          Process.sleep(100)

          request =
            Finch.build(
              :get,
              "http://localhost:7777/httpbin/anything",
              [{"authorization", "bearer #{access_token.value}"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, status: 200}} =
                   Finch.request(request, HttpClient)

          assert %{
                   "headers" => %{
                     "Authorization" => authorization,
                     "X-Forwarded-Authorization" => forwarded_authorization
                   }
                 } = Jason.decode!(body)

          assert [_authorization_header, token] = Regex.run(~r/bearer (.+)/, authorization)

          upstream = Repo.all(Upstream) |> List.first()
          signer = Upstreams.Client.signer(upstream)
          assert {:ok, claims} = Upstreams.Client.Token.verify(token, signer)
          assert claims["client_id"] == access_token.client.id
          assert claims["value"] == access_token.value

          assert forwarded_authorization == "bearer #{access_token.value}"
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end
end
