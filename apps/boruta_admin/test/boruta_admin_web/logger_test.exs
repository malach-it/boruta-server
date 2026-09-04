defmodule BorutaAdminWeb.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Plug.Conn
  import Plug.Test, only: [conn: 2, conn: 3]

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  test "logs the admin resource identifier but no request data" do
    log =
      capture_log([level: :info], fn ->
        :post
        |> conn("/api/roles/role-id?private-query=value", %{private_body: "value"})
        |> Map.put(:path_params, %{"id" => "role-id"})
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :update)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(200, "")
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin role update - success"))

    assert business_log =~ "role_id=role-id"
    refute business_log =~ "private-query"
    refute business_log =~ "private_body"
    refute business_log =~ "status="
  end

  test "logs nested resource identifiers as safe attributes" do
    log =
      capture_log([level: :info], fn ->
        :patch
        |> conn("/api/identity-providers/provider-id/templates/login")
        |> Map.put(:path_params, %{
          "identity_provider_id" => "provider-id",
          "template_type" => "login template\nforged=true"
        })
        |> put_private(:phoenix_controller, BorutaAdminWeb.IdentityProviderController)
        |> put_private(:phoenix_action, :update_template)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(200, "")
      end)

    assert log =~
             "boruta_admin identity_provider update_template - success identity_provider_id=provider-id template_type=login+template%0Aforged%3Dtrue"
  end

  test "logs only explicitly allowlisted parameters" do
    log =
      capture_log([level: :info], fn ->
        :post
        |> conn("/api/upstreams", %{
          "upstream" => %{
            "scheme" => "https",
            "port" => 443,
            "mtls_enabled" => true,
            "host" => "private.example.com",
            "forwarded_token_secret" => "secret-value"
          },
          "unlisted" => "private-value"
        })
        |> put_private(:phoenix_controller, BorutaAdminWeb.UpstreamController)
        |> put_private(:phoenix_action, :create)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(201, "")
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin upstream create - success"))

    assert business_log =~ "scheme=https"
    assert business_log =~ "port=443"
    assert business_log =~ "mtls_enabled=true"
    refute business_log =~ "private.example.com"
    refute business_log =~ "secret-value"
    refute business_log =~ "private-value"
  end

  test "does not log an allowlisted parameter for an unrelated action" do
    log =
      capture_log([level: :info], fn ->
        :get
        |> conn("/api/upstreams")
        |> Map.put(:params, %{"upstream" => %{"scheme" => "ignored-value"}})
        |> put_private(:phoenix_controller, BorutaAdminWeb.UpstreamController)
        |> put_private(:phoenix_action, :index)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(200, "")
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin upstream index - success"))

    refute business_log =~ "ignored-value"
  end

  test "logs allowlisted client policy parameters and identifiers" do
    log =
      capture_log([level: :info], fn ->
        :post
        |> conn("/api/clients", %{
          "client" => %{
            "id" => "client-id",
            "confidential" => true,
            "supported_grant_types" => ["authorization_code", "refresh_token"],
            "token_endpoint_auth_methods" => ["client_secret_basic"],
            "id_token_signature_alg" => "RS512",
            "redirect_uris" => ["https://private.example.com/callback"],
            "secret" => "client-secret"
          }
        })
        |> put_private(:phoenix_controller, BorutaAdminWeb.ClientController)
        |> put_private(:phoenix_action, :create)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(201, "")
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin client create - success"))

    assert business_log =~ "client_id=client-id"
    assert business_log =~ "confidential=true"
    assert business_log =~ "supported_grant_types=authorization_code%2Crefresh_token"
    assert business_log =~ "token_endpoint_auth_methods=client_secret_basic"
    assert business_log =~ "id_token_signature_alg=RS512"
    refute business_log =~ "private.example.com"
    refute business_log =~ "client-secret"
  end

  test "logs failed admin actions" do
    log =
      capture_log([level: :info], fn ->
        :delete
        |> conn("/api/roles/id")
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :delete)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(403, "")
      end)

    assert log =~ "boruta_admin role delete - failure"
  end

  test "logs only the code and message from failed admin responses" do
    log =
      capture_log([level: :info], fn ->
        :patch
        |> conn("/api/roles/role-id")
        |> Map.put(:path_params, %{"id" => "role-id"})
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :update)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> put_resp_content_type("application/json")
        |> send_resp(
          422,
          Jason.encode!(%{
            code: "UNPROCESSABLE_ENTITY",
            message: "Your request could not be processed.",
            errors: %{name: ["private validation detail"]},
            secret: "private response value"
          })
        )
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin role update - failure"))

    assert business_log =~
             ~r/role_id=role-id code=UNPROCESSABLE_ENTITY message=Your\+request\+could\+not\+be\+processed\.$/

    refute business_log =~ "private validation detail"
    refute business_log =~ "private response value"
  end

  test "does not log response error fields from successful admin actions" do
    log =
      capture_log([level: :info], fn ->
        :patch
        |> conn("/api/roles/role-id")
        |> Map.put(:path_params, %{"id" => "role-id"})
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :update)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{code: "NOT_AN_ERROR", message: "private value"}))
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin role update - success"))

    refute business_log =~ "code="
    refute business_log =~ "message="
    refute business_log =~ "private value"
  end

  test "logs the authenticated user subject" do
    log =
      capture_log([level: :info], fn ->
        :patch
        |> conn("/api/roles/role-id")
        |> Map.put(:path_params, %{"id" => "role-id"})
        |> assign(:authorization, %{"scope" => "scopes:manage:all", "sub" => "user-sub"})
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :update)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(200, "")
      end)

    assert log =~ "boruta_admin role update - success sub=user-sub role_id=role-id"
  end

  test "logs successful console authentication without credentials" do
    log =
      capture_log([level: :info], fn ->
        :telemetry.execute(
          [:boruta_admin, :console, :authentication, :success],
          %{},
          %{
            client_id: "client-id",
            sub: "console-user@console-host",
            request_id: "console-request-id"
          }
        )
      end)

    assert log =~
             "boruta_admin console authenticate - success client_id=client-id sub=console-user%40console-host"

    refute log =~ "client_secret"
    refute log =~ "access_token"
  end

  test "logs failed console authentication" do
    log =
      capture_log([level: :info], fn ->
        :telemetry.execute(
          [:boruta_admin, :console, :authentication, :failure],
          %{},
          %{
            client_id: "client-id",
            sub: "console-user@console-host",
            request_id: "console-request-id"
          }
        )
      end)

    assert log =~
             "boruta_admin console authenticate - failure client_id=client-id sub=console-user%40console-host"
  end

  test "omits the subject when authentication did not establish a principal" do
    log =
      capture_log([level: :info], fn ->
        :get
        |> conn("/api/roles")
        |> put_private(:phoenix_controller, BorutaAdminWeb.RoleController)
        |> put_private(:phoenix_action, :index)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(401, "")
      end)

    business_log =
      log
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "boruta_admin role index - failure"))

    refute business_log =~ "sub="
  end

  test "does not log browser requests as business events" do
    log =
      capture_log([level: :info], fn ->
        :get
        |> conn("/")
        |> put_private(:phoenix_controller, BorutaAdminWeb.PageController)
        |> put_private(:phoenix_action, :index)
        |> BorutaAdminWeb.Logger.call(BorutaAdminWeb.Logger.init([]))
        |> send_resp(200, "")
      end)

    refute log =~ "boruta_admin page index - success"
  end
end
