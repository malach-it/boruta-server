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

  import BorutaIdentity.AccountsFixtures

  alias Boruta.Ecto.OauthMapper
  alias Boruta.Oauth.IntrospectResponse
  alias Ecto.Adapters.SQL.Sandbox

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
    :ok = Sandbox.checkout(BorutaAdmin.Repo)
    :ok = Sandbox.checkout(BorutaAuth.Repo)
    :ok = Sandbox.checkout(BorutaGateway.Repo)
    :ok = Sandbox.checkout(BorutaIdentity.Repo)
    :ok = Sandbox.checkout(BorutaWeb.Repo)

    unless tags[:async] do
      Sandbox.mode(BorutaAuth.Repo, {:shared, self()})
      Sandbox.mode(BorutaAdmin.Repo, {:shared, self()})
      Sandbox.mode(BorutaGateway.Repo, {:shared, self()})
      Sandbox.mode(BorutaIdentity.Repo, {:shared, self()})
      Sandbox.mode(BorutaWeb.Repo, {:shared, self()})
    end

    conn = Phoenix.ConnTest.build_conn()

    {:ok, merge_tags_params(conn, tags)}
  end

  def merge_tags_params(conn, tags) do
    Enum.reduce(tags, [conn: conn], fn
      {:authorized, scopes}, params ->
        Keyword.merge(
          params,
          authorized_params(conn, scopes)
        )

      {:user_authorized, scopes}, params ->
        Keyword.merge(
          params,
          user_authorized_params(conn, scopes)
        )

      _, params ->
        params
    end)
  end

  def authorized_params(conn, scopes) do
    token =
      Boruta.Factory.insert(
        :token,
        type: "access_token",
        scope: Enum.join(scopes, " ")
      )

    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token.value}")

    [conn: conn]
  end

  def user_authorized_params(conn, scopes) do
    %{id: sub} = user_fixture()
    resource_owner = %Boruta.Oauth.ResourceOwner{sub: sub}

    token =
      Boruta.Factory.insert(:token,
        type: "access_token",
        scope: Enum.join(scopes, " "),
        sub: resource_owner.sub
      )

    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token.value}")

    # TODO test external oauth provider
    # %URI{port: port} =
    #   URI.parse(
    #     Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:oauth2][
    #       :site
    #     ]
    #   )

    # bypass = Bypass.open(port: port)
    # Bypass.up(bypass)

    # userinfo =
    #   with {:ok, token} <- Boruta.Oauth.Token.userinfo(token) do
    #     UserinfoResponse.from_userinfo(token, token.client)
    #     |> UserinfoResponse.payload()
    #   end

    # Bypass.stub(bypass, "POST", "/oauth/userinfo", fn conn ->
    #   Plug.Conn.resp(conn, 200, Jason.encode!(userinfo))
    # end)

    [conn: conn, resource_owner: resource_owner]
  end
end
