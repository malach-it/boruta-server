defmodule BorutaGateway.BasicForwardingTest do
  use ExUnit.Case, async: false
  use BorutaGateway.DataCase

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.ClientStore
  alias BorutaGateway.{Certificate, HttpGateway, HttpsGateway}
  alias BorutaGateway.Upstreams.Upstream

  defmodule ResourceOwners do
    def get_by(username: "alice"),
      do: {:ok, %Boruta.Oauth.ResourceOwner{sub: "basic-user", username: "alice"}}

    def get_by(_), do: {:error, :not_found}
    def check_password(_, "password"), do: :ok
    def check_password(_, _), do: {:error, :invalid_password}
    def authorized_scopes(_), do: ["read"]
  end

  setup do
    previous_adapter = Application.get_env(:boruta_gateway, :basic_authorization_resource_owners)
    previous_public = ClientStore.get_public()
    {:ok, client} = Admin.create_client(%{access_token_ttl: 3600})
    public = Boruta.ClientsAdapter.get_client(client.id)
    {:ok, ^public} = ClientStore.put_public(public)
    Application.put_env(:boruta_gateway, :basic_authorization_resource_owners, ResourceOwners)

    on_exit(fn ->
      if previous_adapter,
        do:
          Application.put_env(
            :boruta_gateway,
            :basic_authorization_resource_owners,
            previous_adapter
          ),
        else: Application.delete_env(:boruta_gateway, :basic_authorization_resource_owners)

      case previous_public do
        {:ok, client} -> ClientStore.put_public(client)
        _ -> ClientStore.invalidate_public()
      end
    end)

    {:ok, public: public}
  end

  for {gateway_module, transport, scheme} <- [
        {HttpGateway, :gen_tcp, :http},
        {HttpsGateway, :ssl, :https}
      ] do
    @gateway_module gateway_module
    @transport transport
    @scheme scheme

    test "#{scheme} Basic forwarding carries a persisted bearer and unspoofed metadata", %{
      public: public
    } do
      {:ok, upstream_socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, {_, upstream_port}} = :inet.sockname(upstream_socket)
      on_exit(fn -> :gen_tcp.close(upstream_socket) end)

      upstream = %Upstream{
        id: Ecto.UUID.generate(),
        scheme: "http",
        host: "127.0.0.1",
        port: upstream_port,
        uris: ["/basic"],
        strip_uri: true,
        authorize: true,
        authorization_type: "http_basic",
        required_scopes: %{"GET" => ["read"]}
      }

      {:ok, spare} = :gen_tcp.listen(0, [:binary, active: false])
      {:ok, {_, port}} = :inet.sockname(spare)
      :gen_tcp.close(spare)

      options = [port: port, num_acceptors: 1, match_function: fn _, _ -> upstream end]

      options =
        if @transport == :ssl,
          do: options ++ [ssl_options: tls_options(), verify_client_certificate: false],
          else: options

      start_supervised!(%{
        id: :basic_forwarding_gateway,
        start: {Module.concat(@gateway_module, Server), :start, [options]}
      })

      upstream_task =
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.accept(upstream_socket, 3_000)
          {:ok, request} = :gen_tcp.recv(socket, 0, 3_000)
          :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
          :gen_tcp.close(socket)
          request
        end)

      socket_options =
        [:binary, active: false] ++ if(@transport == :ssl, do: [verify: :verify_none], else: [])

      {:ok, socket} = @transport.connect(~c"127.0.0.1", port, socket_options, 3_000)
      basic = "Basic " <> Base.encode64("alice:password")

      :ok =
        @transport.send(
          socket,
          "GET /basic/users HTTP/1.1\r\nHost: admin.localhost:8082\r\n" <>
            "Authorization: #{basic}\r\nForwarded: for=spoofed\r\n" <>
            "X-Forwarded-Authorization: Bearer spoofed\r\nX-Real-IP: 203.0.113.99\r\n\r\n"
        )

      assert {:ok, "HTTP/1.1 204 No Content" <> _} = @transport.recv(socket, 0, 3_000)
      @transport.close(socket)
      request = Task.await(upstream_task, 3_000)

      assert request =~ "GET /users HTTP/1.1\r\n"
      assert request =~ "X-Forwarded-Authorization: #{basic}\r\n"
      assert request =~ ~s(Forwarded: for=127.0.0.1;proto=#{@scheme};host="admin.localhost:8082")
      refute request =~ "spoofed"
      [_, bearer] = Regex.run(~r/(?:^|\r\n)Authorization: Bearer ([^\r\n]+)/, request)
      assert {:ok, token} = Boruta.Oauth.Authorization.AccessToken.authorize(value: bearer)
      assert token.scope == "read"
      assert token.sub == "basic-user"
      assert token.client.id == public.id

      assert token.expires_at ==
               DateTime.to_unix(token.inserted_at) + token.client.access_token_ttl

      assert {:ok, _} = Boruta.AccessTokensAdapter.revoke(token)
    end
  end

  defp tls_options do
    directory =
      Path.join(System.tmp_dir!(), "boruta-basic-tls-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    File.chmod!(directory, 0o700)
    on_exit(fn -> File.rm_rf!(directory) end)
    cert = Path.join(directory, "certificate.pem")
    key = Path.join(directory, "key.pem")

    {_, 0} =
      System.cmd(
        "openssl",
        [
          "req",
          "-x509",
          "-newkey",
          "rsa:2048",
          "-nodes",
          "-days",
          "1",
          "-subj",
          "/CN=localhost",
          "-keyout",
          key,
          "-out",
          cert
        ],
        stderr_to_stdout: true
      )

    Certificate.ssl_options(cert, key)
  end
end
