defmodule BorutaGateway.RequestsIntegrationTest do
  use ExUnit.Case, async: false
  use BorutaGateway.DataCase

  alias Boruta.AccessTokensAdapter
  alias Boruta.ClientsAdapter
  alias Boruta.Ecto.Admin
  alias BorutaAuth.Plugs.RateLimit.Counter
  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.HttpGateway
  alias BorutaGateway.Repo
  alias BorutaGateway.RequestsIntegrationTest.HttpClient
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  setup_all do
    Finch.start_link(name: HttpClient)

    :ok
  end

  describe "requests" do
    setup do
      {:ok, %Boruta.Ecto.Client{id: client_id}} = Admin.create_client(%{})

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

    test "returns a 404 when no upstream persisted" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          parent = self()
          handler_id = :gateway_real_ip_test

          :telemetry.attach(
            handler_id,
            [:boruta_gateway, :request, :stop],
            fn _event, _measurements, metadata, _config ->
              send(parent, {:gateway_request_log, metadata})
            end,
            :ok
          )

          request =
            Finch.build(
              :get,
              "http://localhost:7777/no_upstream",
              [{"x-real-ip", "203.0.113.1"}],
              ""
            )

          assert {:ok, %Finch.Response{body: body, status: 404}} =
                   Finch.request(request, HttpClient)

          assert body == "No upstream has been found corresponding to the given request."

          assert_receive {:gateway_request_log, %{remote_ip: "203.0.113.1"}}
        after
          :telemetry.detach(:gateway_real_ip_test)
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns a 400 for malformed request lines" do
      {:ok, socket} =
        :gen_tcp.connect(~c"localhost", 7777, [:binary, {:packet, :raw}, {:active, false}], 1_000)

      :ok = :gen_tcp.send(socket, "BAD\r\n\r\n")

      assert {:ok, response} = :gen_tcp.recv(socket, 0, 1_000)
      assert response =~ "HTTP/1.1 400 Bad Request"

      :gen_tcp.close(socket)
    end

    test "closes oversized upstream response buffers" do
      previous_max_response_buffer_bytes =
        Application.get_env(:boruta_gateway, :max_response_buffer_bytes)

      Application.put_env(:boruta_gateway, :max_response_buffer_bytes, 64)

      on_exit(fn ->
        case previous_max_response_buffer_bytes do
          nil ->
            Application.delete_env(:boruta_gateway, :max_response_buffer_bytes)

          value ->
            Application.put_env(:boruta_gateway, :max_response_buffer_bytes, value)
        end
      end)

      with_upstream_server(
        fn request ->
          assert request =~ "GET /large HTTP/1.1"

          response_body(String.duplicate("a", 100), status: "200 OK", content_type: "text/plain")
        end,
        fn port ->
          Sandbox.unboxed_run(Repo, fn ->
            try do
              Upstreams.create_upstream(%{
                scheme: "http",
                host: "127.0.0.1",
                port: port,
                uris: ["/large"],
                authorize: false
              })

              Process.sleep(100)

              request = Finch.build(:get, "http://localhost:7777/large", [], "")

              assert {:ok, %Finch.Response{status: 502}} = Finch.request(request, HttpClient)
            after
              Repo.delete_all(Upstream)
            end
          end)
        end
      )
    end

    test "generates request ids with secure random entropy when none is provided" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          parent = self()
          handler_id = :gateway_request_id_test

          :telemetry.attach(
            handler_id,
            [:boruta_gateway, :request, :stop],
            fn _event, _measurements, metadata, _config ->
              send(parent, {:gateway_request_log, metadata})
            end,
            :ok
          )

          request = Finch.build(:get, "http://localhost:7777/no_upstream", [], "")

          assert {:ok, %Finch.Response{body: body, status: 404}} =
                   Finch.request(request, HttpClient)

          assert body == "No upstream has been found corresponding to the given request."

          assert_receive {:gateway_request_log, %{request_id: request_id}}
          assert request_id =~ ~r/^[0-9a-f]{8}$/
        after
          :telemetry.detach(:gateway_request_id_test)
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

    test "returns a 429 when upstream rate limit is reached" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, upstream} =
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "should.not.be.called",
              port: 80,
              uris: ["/limited"],
              rate_limit_enabled: true,
              rate_limit_count: 1,
              rate_limit_time_unit: "second",
              rate_limit_penality: 100,
              rate_limit_timeout: 1,
              rate_limit_memory_length: 50
            })

          key = {:gateway_upstream, upstream.id, ~c"127.0.0.1"}

          Agent.update(Counter, fn _counter ->
            %{key => List.duplicate(:os.system_time(:millisecond), 7)}
          end)

          Process.sleep(100)

          request = Finch.build(:get, "http://127.0.0.1:7777/limited", [], "")

          assert {:ok, %Finch.Response{body: "", status: 429}} =
                   Finch.request(request, HttpClient)
        after
          Agent.update(Counter, fn _counter -> %{} end)
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns response when authorized", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&teapot_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
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
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "logs successful requests" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          parent = self()
          handler_id = :gateway_successful_request_log_test

          :telemetry.attach(
            handler_id,
            [:boruta_gateway, :request, :stop],
            fn _event, measurements, metadata, _config ->
              send(parent, {:gateway_request_log, measurements, metadata})
            end,
            :ok
          )

          with_upstream_server(&teapot_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/httpbin"],
              strip_uri: true
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/httpbin/status/418", [], "")

            assert {:ok, %Finch.Response{body: body, status: 418}} =
                     Finch.request(request, HttpClient)

            assert body =~ ~r/teapot/
            assert_receive {:gateway_request_log, %{duration: duration}, %{status: 418}}
            assert duration > 0
          end)
        after
          :telemetry.detach(:gateway_successful_request_log_test)
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns response when exact upstream uri is stripped" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&root_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/httpbin"],
              strip_uri: true
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/httpbin", [], "")

            assert {:ok, %Finch.Response{body: body, status: 200}} =
                     Finch.request(request, HttpClient)

            assert body == "root"
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns response root uri stripped", %{access_token: access_token} do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&teapot_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/"],
              strip_uri: true,
              authorize: true,
              required_scopes: %{"GET" => ["test"]}
            })

            Process.sleep(100)

            request =
              Finch.build(
                :get,
                "http://localhost:7777/status/418",
                [{"authorization", "Bearer #{access_token.value}"}],
                ""
              )

            assert {:ok, %Finch.Response{body: body, status: 418}} =
                     Finch.request(request, HttpClient)

            assert body =~ ~r/teapot/
          end)
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
          with_upstream_server(&echo_headers_response/1, fn port ->
            {:ok, upstream} =
              Upstreams.create_upstream(%{
                scheme: "http",
                host: "127.0.0.1",
                port: port,
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
            signer = HttpGateway.signer(upstream)
            assert {:ok, claims} = HttpGateway.Token.verify(token, signer)
            assert claims["client_id"] == access_token.client.id
            assert claims["value"] == access_token.value

            assert forwarded_authorization == "bearer #{access_token.value}"
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns close-delimited response without content length" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&close_delimited_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/close-delimited"]
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/close-delimited", [], "")

            assert {:ok, %Finch.Response{body: "close-delimited", status: 200}} =
                     Finch.request(request, HttpClient)
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns bodyless response without content length" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&no_content_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/no-content"]
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/no-content", [], "")

            assert {:ok, %Finch.Response{body: "", status: 204}} =
                     Finch.request(request, HttpClient)
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "returns chunked response" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&chunked_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/chunked"]
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/chunked", [], "")

            assert {:ok, %Finch.Response{body: "hello", status: 200}} =
                     Finch.request(request, HttpClient)
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "does not forward hop-by-hop request headers" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&echo_headers_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/headers"]
            })

            Process.sleep(100)

            request =
              Finch.build(
                :get,
                "http://localhost:7777/headers",
                [
                  {"connection", "keep-alive"},
                  {"keep-alive", "timeout=5"},
                  {"upgrade", "websocket"},
                  {"x-forwarded-authorization", "bearer stale"}
                ],
                ""
              )

            assert {:ok, %Finch.Response{body: body, status: 200}} =
                     Finch.request(request, HttpClient)

            assert %{"headers" => headers} = Jason.decode!(body)
            refute Map.has_key?(headers, "Connection")
            refute Map.has_key?(headers, "Keep-Alive")
            refute Map.has_key?(headers, "Upgrade")
            refute Map.has_key?(headers, "X-Forwarded-Authorization")
            assert headers["Host"] == "127.0.0.1"
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "does not forward hop-by-hop response headers" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          with_upstream_server(&response_headers_cleanup_response/1, fn port ->
            Upstreams.create_upstream(%{
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/response-headers"]
            })

            Process.sleep(100)

            request = Finch.build(:get, "http://localhost:7777/response-headers", [], "")

            assert {:ok, %Finch.Response{body: "headers-cleaned", headers: headers, status: 200}} =
                     Finch.request(request, HttpClient)

            header_names = Enum.map(headers, fn {name, _value} -> name end)
            refute "connection" in header_names
            refute "keep-alive" in header_names
            refute "strict-transport-security" in header_names
            refute "upgrade" in header_names
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end

  describe "requests (from configuration file)" do
    setup do
      {:ok, %Boruta.Ecto.Client{id: client_id}} = Admin.create_client(%{})

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
          with_upstream_server(&teapot_response/1, fn port ->
            configuration_file_path = authorized_configuration_file(port)

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
          end)
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
          with_upstream_server(&echo_headers_response/1, fn port ->
            configuration_file_path = authorized_configuration_file(port, introspect: true)

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
            signer = HttpGateway.signer(upstream)
            assert {:ok, claims} = HttpGateway.Token.verify(token, signer)
            assert claims["client_id"] == access_token.client.id
            assert claims["value"] == access_token.value

            assert forwarded_authorization == "bearer #{access_token.value}"
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end

  describe "sidecar requests" do
    setup do
      {:ok, %Boruta.Ecto.Client{id: client_id}} = Admin.create_client(%{})

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
            node_name: ConfigurationLoader.node_name(),
            scheme: "http",
            host: "should.not.be.called",
            port: 80,
            uris: ["/upstream"]
          })

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7778/no_upstream", [], "")

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
              node_name: ConfigurationLoader.node_name(),
              scheme: "http",
              host: "should.not.be.called",
              port: 80,
              uris: ["/unauthorized"],
              authorize: true,
              error_content_type: "text",
              unauthorized_response: "boom"
            })

          Process.sleep(100)

          request = Finch.build(:get, "http://localhost:7778/unauthorized", [], "")

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
              node_name: ConfigurationLoader.node_name(),
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
              "http://localhost:7778/forbidden",
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
          with_upstream_server(&teapot_response/1, fn port ->
            Upstreams.create_upstream(%{
              node_name: ConfigurationLoader.node_name(),
              scheme: "http",
              host: "127.0.0.1",
              port: port,
              uris: ["/httpbin"],
              strip_uri: true,
              authorize: true,
              required_scopes: %{"GET" => ["test"]}
            })

            Process.sleep(100)

            request =
              Finch.build(
                :get,
                "http://localhost:7778/httpbin/status/418",
                [{"authorization", "Bearer #{access_token.value}"}],
                ""
              )

            assert {:ok, %Finch.Response{body: body, status: 418}} =
                     Finch.request(request, HttpClient)

            assert body =~ ~r/teapot/
          end)
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
          with_upstream_server(&echo_headers_response/1, fn port ->
            {:ok, upstream} =
              Upstreams.create_upstream(%{
                node_name: ConfigurationLoader.node_name(),
                scheme: "http",
                host: "127.0.0.1",
                port: port,
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
                "http://localhost:7778/httpbin/anything",
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
            signer = HttpGateway.signer(upstream)
            assert {:ok, claims} = HttpGateway.Token.verify(token, signer)
            assert claims["client_id"] == access_token.client.id
            assert claims["value"] == access_token.value

            assert forwarded_authorization == "bearer #{access_token.value}"
          end)
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end

  defp with_upstream_server(response_fun, test_fun) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        :binary,
        {:packet, :raw},
        {:active, false},
        {:ip, {127, 0, 0, 1}},
        {:reuseaddr, true}
      ])

    {:ok, {_address, port}} = :inet.sockname(listen_socket)

    task =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
        :ok = :gen_tcp.send(socket, response_fun.(request))
        :gen_tcp.close(socket)
        :gen_tcp.close(listen_socket)
      end)

    try do
      test_fun.(port)
      Task.await(task, 1_000)
    after
      :gen_tcp.close(listen_socket)
      Task.shutdown(task, :brutal_kill)
    end
  end

  defp teapot_response(request) do
    assert request =~ "GET /status/418 HTTP/1.1"

    response_body("I'm a teapot", status: "418 I'm a teapot", content_type: "text/plain")
  end

  defp root_response(request) do
    assert request =~ "GET / HTTP/1.1"

    response_body("root", content_type: "text/plain")
  end

  defp echo_headers_response(request) do
    body = Jason.encode!(%{"headers" => request_headers(request)})

    response_body(body, content_type: "application/json")
  end

  defp close_delimited_response(request) do
    assert request =~ "GET /close-delimited HTTP/1.1"

    "HTTP/1.1 200 OK\r\n" <>
      "Content-Type: text/plain\r\n\r\n" <>
      "close-delimited"
  end

  defp no_content_response(request) do
    assert request =~ "GET /no-content HTTP/1.1"

    "HTTP/1.1 204 No Content\r\n\r\n"
  end

  defp chunked_response(request) do
    assert request =~ "GET /chunked HTTP/1.1"

    "HTTP/1.1 200 OK\r\n" <>
      "Transfer-Encoding: chunked\r\n\r\n" <>
      "5\r\nhello\r\n" <>
      "0\r\n\r\n"
  end

  defp response_headers_cleanup_response(request) do
    assert request =~ "GET /response-headers HTTP/1.1"

    "HTTP/1.1 200 OK\r\n" <>
      "Connection: keep-alive\r\n" <>
      "Keep-Alive: timeout=5\r\n" <>
      "Strict-Transport-Security: max-age=31536000\r\n" <>
      "Upgrade: websocket\r\n" <>
      "Content-Type: text/plain\r\n" <>
      "Content-Length: 15\r\n\r\n" <>
      "headers-cleaned"
  end

  defp response_body(body, options) do
    status = Keyword.get(options, :status, "200 OK")
    content_type = Keyword.fetch!(options, :content_type)

    "HTTP/1.1 #{status}\r\n" <>
      "Content-Type: #{content_type}\r\n" <>
      "Content-Length: #{byte_size(body)}\r\n\r\n" <>
      body
  end

  defp request_headers(request) do
    request
    |> String.split("\r\n\r\n", parts: 2)
    |> List.first()
    |> String.split("\r\n")
    |> Enum.drop(1)
    |> Enum.reduce(%{}, fn header, headers ->
      case String.split(header, ": ", parts: 2) do
        [name, value] -> Map.put(headers, name, value)
        _ -> headers
      end
    end)
  end

  defp authorized_configuration_file(port, options \\ []) do
    introspect? = Keyword.get(options, :introspect, false)

    forwarded_token_signature_alg =
      if introspect?, do: ~s|      forwarded_token_signature_alg: "HS256"\n|, else: ""

    path = Path.join(System.tmp_dir!(), "boruta_gateway_authorized_#{port}.yml")

    File.write!(path, """
    ---
    configuration:
      gateway:
        - host: "127.0.0.1"
          port: #{port}
          uris: ["/httpbin"]
          scheme: "http"
          strip_uri: true
          authorize: true
          required_scopes:
            GET: ["test"]
    #{forwarded_token_signature_alg}\
    """)

    path
  end
end
