defmodule BorutaWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import BorutaWeb.ChannelCase

      # The default endpoint for testing
      @endpoint BorutaWeb.Endpoint
    end
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
