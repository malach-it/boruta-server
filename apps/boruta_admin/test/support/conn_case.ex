defmodule BorutaAdminWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BorutaAdminWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BorutaAdminWeb.ConnCase

      alias BorutaAdminWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BorutaAdminWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BorutaAdmin.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BorutaGateway.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BorutaIdentity.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BorutaWeb.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(BorutaAdmin.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def with_authenticated_user(context) do
    %URI{port: port} =
      URI.parse(
        Application.get_env(:boruta_web, BorutaWeb.Authorization)[:oauth2][
          :site
        ]
      )
    bypass = Bypass.open(port: port)
    Bypass.up(bypass)

    introspected_token = %{
      "active" => true,
      "sub" => "sub",
      "scope" => context[:scope] || "",
      "username" => "username@test.test"
    }

    Bypass.stub(bypass, "POST", "/oauth/introspect", fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!(introspected_token))
    end)
    [bypass: bypass, introspected_token: introspected_token]
  end
end
