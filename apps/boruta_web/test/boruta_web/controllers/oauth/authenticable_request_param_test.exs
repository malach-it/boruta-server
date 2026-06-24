defmodule BorutaWeb.Oauth.AuthenticableRequestParamTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory

  alias BorutaIdentityWeb.Authenticable
  alias BorutaIdentityWeb.Token

  test "request_param drops prompt and max_age without rewriting other parameter values", %{
    conn: conn
  } do
    redirect_uri = "http://redirect.uri"
    client = insert(:client, redirect_uris: [redirect_uri])
    scope = insert(:scope)

    request =
      conn
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: scope.name,
          prompt: "login",
          max_age: "10",
          state: "keep prompt=none and max_age=10"
        })
      )
      |> Authenticable.request_param()

    assert {:ok, %{"user_return_to" => user_return_to}} =
             Token.verify(request, Token.application_signer())

    uri = URI.parse(user_return_to)
    query = URI.decode_query(uri.query)

    refute Map.has_key?(query, "prompt")
    refute Map.has_key?(query, "max_age")
    assert query["state"] == "keep prompt=none and max_age=10"
  end
end
