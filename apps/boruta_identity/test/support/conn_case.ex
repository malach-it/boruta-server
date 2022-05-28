defmodule BorutaIdentityWeb.ConnCase do
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
  by setting `use BorutaIdentityWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo
  alias BorutaIdentityWeb.Authenticable
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BorutaIdentityWeb.ConnCase

      alias BorutaIdentityWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BorutaIdentityWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(BorutaIdentity.Repo)
    :ok = Sandbox.checkout(BorutaAuth.Repo)

    unless tags[:async] do
      Sandbox.mode(BorutaIdentity.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in

  It stores an updated connection and a registered user in the
  test context.
  """
  # TODO typespec
  def register_and_log_in(%{conn: conn}) do
    user = BorutaIdentity.AccountsFixtures.user_fixture()
    %{conn: log_in(conn, user), user: user}
  end

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(user :: User.t()) :: token :: String.t()
  def generate_user_session_token(%User{id: user_id}) do
    user = Repo.get!(User, user_id)
    User.login_changeset(user, Internal) |> Repo.update()

    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  # TODO typespec
  def log_in(conn, user, params \\ %{}) do
    token = generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Map.put(:body_params, params)
    |> Authenticable.store_user_session(token)
  end

  def with_a_request(_params) do
    relying_party =
      BorutaIdentity.Factory.insert(:relying_party,
        registrable: true,
        consentable: true,
        confirmable: true,
        user_editable: true
      )

    client = Boruta.Factory.insert(:client)
    scope = Boruta.Factory.insert(:scope, name: "request:scope", label: "Scope from request")

    client_relying_party =
      BorutaIdentity.Factory.insert(:client_relying_party,
        relying_party: relying_party,
        client_id: client.id
      )

    {:ok, jwt, _payload} =
      Joken.encode_and_sign(
        %{
          client_id: client_relying_party.client_id,
          scope: scope.name,
          user_return_to: "/user_return_to"
        },
        BorutaIdentityWeb.Token.application_signer()
      )

    %{request: jwt, relying_party: relying_party, client: client}
  end
end
