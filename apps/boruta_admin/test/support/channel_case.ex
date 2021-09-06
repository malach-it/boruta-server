defmodule BorutaAdminWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BorutaAdminWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import BorutaAdminWeb.ChannelCase

      # The default endpoint for testing
      @endpoint BorutaAdminWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(BorutaAdmin.Repo)
    :ok = Sandbox.checkout(BorutaGateway.Repo)
    :ok = Sandbox.checkout(BorutaIdentity.Repo)
    :ok = Sandbox.checkout(BorutaWeb.Repo)

    unless tags[:async] do
      Sandbox.mode(BorutaAdmin.Repo, {:shared, self()})
      Sandbox.mode(BorutaGateway.Repo, {:shared, self()})
      Sandbox.mode(BorutaIdentity.Repo, {:shared, self()})
      Sandbox.mode(BorutaWeb.Repo, {:shared, self()})
    end

    :ok
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
