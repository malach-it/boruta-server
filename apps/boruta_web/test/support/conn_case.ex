defmodule BorutaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Boruta.Ecto.Scopes
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BorutaIdentityWeb.ConnCase
      import BorutaWeb.ConnCase

      alias BorutaWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BorutaWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(BorutaIdentity.Repo)
    :ok = Sandbox.checkout(BorutaWeb.Repo)

    :ok = Scopes.invalidate(:public)

    unless tags[:async] do
      Sandbox.mode(BorutaIdentity.Repo, {:shared, self()})
      Sandbox.mode(BorutaWeb.Repo, {:shared, self()})
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
