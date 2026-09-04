defmodule BorutaAdmin.CliTest do
  use BorutaAdminWeb.ConnCase

  import Boruta.Factory
  import ExUnit.CaptureLog

  alias BorutaAdmin.Cli

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  test "persists console authentication and resource action business events" do
    client = insert(:client)
    previous_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
    previous_client_secret = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")
    previous_sub = System.get_env("BORUTA_COMMAND_SUB")

    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", client.secret)
    System.put_env("BORUTA_COMMAND_SUB", "console-user@console-host")

    on_exit(fn ->
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", previous_client_id)
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", previous_client_secret)
      restore_env("BORUTA_COMMAND_SUB", previous_sub)
    end)

    log =
      capture_log([level: :info], fn ->
        assert {:ok, %Plug.Conn{status: 200}} = Cli.call("role", "index")
      end)

    assert log =~
             "boruta_admin console authenticate - success client_id=#{client.id} sub=console-user%40console-host"

    assert log =~ "boruta_admin role index - success sub=console-user%40console-host"

    assert [_, request_id] =
             Regex.run(~r/request_id=([^\s]+).*boruta_admin console authenticate/, log)

    assert [_, ^request_id] = Regex.run(~r/request_id=([^\s]+).*boruta_admin role index/, log)
  end

  test "adds safe call parameters to the resource business event" do
    client = insert(:client)
    previous_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
    previous_client_secret = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", client.secret)

    on_exit(fn ->
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", previous_client_id)
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", previous_client_secret)
    end)

    log =
      capture_log([level: :info], fn ->
        assert {:ok, %Plug.Conn{status: 201}} =
                 Cli.call("upstream", "create", nil, %{
                   "scheme" => "https",
                   "host" => "private.example.com",
                   "port" => "443",
                   "mtls_enabled" => "false",
                   "forwarded_token_secret" => "secret-value",
                   "unlisted" => "private-value"
                 })
      end)

    business_event =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin upstream create - success"))

    assert business_event =~ "scheme=https"
    assert business_event =~ "port=443"
    assert business_event =~ "mtls_enabled=false"
    refute business_event =~ "private.example.com"
    refute business_event =~ "secret-value"
    refute business_event =~ "private-value"
  end

  test "returns a JSON bad request for invalid log parameters" do
    client = insert(:client)
    previous_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
    previous_client_secret = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", client.secret)

    on_exit(fn ->
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", previous_client_id)
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", previous_client_secret)
    end)

    assert {:ok, %Plug.Conn{status: 400, resp_body: body}} =
             Cli.call("logs", "index", nil, %{"application" => "boruat_web"})

    assert %{
             "code" => "BAD_REQUEST",
             "message" => "The requested with given parameters cannot be processed."
           } = Jason.decode!(body)
  end

  test "rejects an invalid client secret and logs the authentication failure" do
    client = insert(:client)
    previous_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
    previous_client_secret = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", "invalid-secret")

    on_exit(fn ->
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", previous_client_id)
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", previous_client_secret)
    end)

    log =
      capture_log([level: :info], fn ->
        assert {:error,
                {:client_authentication,
                 %Boruta.Oauth.Error{
                   status: :unauthorized,
                   error: :invalid_client,
                   error_description: "Invalid client_id or client_secret."
                 }}} = Cli.call("role", "index")
      end)

    assert log =~ "boruta_admin console authenticate - failure client_id=#{client.id}"
  end

  test "rejects a missing client secret" do
    client = insert(:client)
    previous_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
    previous_client_secret = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")
    System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)
    System.delete_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET")

    on_exit(fn ->
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", previous_client_id)
      restore_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", previous_client_secret)
    end)

    assert {:error,
            {:client_authentication,
             %Boruta.Oauth.Error{
               status: :unauthorized,
               error: :invalid_client,
               error_description: "Invalid client_id or client_secret."
             }}} = Cli.call("role", "index")
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
