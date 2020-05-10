defmodule Boruta.Oauth.Authorization.ScopeTest do
  use ExUnit.Case
  use Boruta.DataCase

  import Boruta.Factory
  import Boruta.Ecto.OauthMapper, only: [
    to_oauth_schema: 1
  ]
  import Mox

  alias Boruta.Oauth.Authorization.Scope
  alias Boruta.Support.ResourceOwners
  alias Boruta.Support.User

  describe "with empty scope" do
    test "returns an empty string if nil given" do
      case Scope.authorize(scope: nil, against: %{}) do
        {:ok, scope} ->
          assert scope == ""
        _ ->
          assert false
      end
    end

    test "returns an empty string if an empty string given" do
      case Scope.authorize(scope: "", against: %{}) do
        {:ok, scope} ->
          assert scope == ""
        _ ->
          assert false
      end
    end
  end

  describe "with a client" do
    setup do
      client = insert(:client)
      public_scope = insert(:scope, public: true)
      private_scope = insert(:scope, public: false)
      client_with_scope = insert(
        :client,
        authorize_scope: true,
        authorized_scopes: [
          private_scope,
          public_scope
        ]
      )
      {:ok,
        client: to_oauth_schema(client),
        private_scope: to_oauth_schema(private_scope),
        public_scope: to_oauth_schema(public_scope),
        client_with_scope: to_oauth_schema(client_with_scope)
      }
    end

    test "returns an error if private scope given", %{
      client: client,
      private_scope: private_scope
    } do
      given_scope = Enum.join(["any", private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{client: client}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some private scope are unknown or unauthorized by the client", %{
      client_with_scope: client,
      private_scope: private_scope
    } do
      given_scope = Enum.join(["any", private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{client: client}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some non existing scope given", %{
      client: client
    } do
      given_scope = Enum.join(["any1", "any2"], " ")

      assert Scope.authorize(scope: given_scope, against: %{client: client}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns scope if some public scope given", %{
      client: client,
      public_scope: public_scope
    } do
      given_scope = Enum.join([public_scope.name], " ")
      authorized_scope = Scope.authorize(scope: given_scope, against: %{client: client})

      assert authorized_scope == {:ok, given_scope}
    end

    test "returns scope if some private scope are authorized by the client", %{
      client_with_scope: client,
      private_scope: private_scope
    } do
      given_scope = Enum.join([private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{client: client}) == {:ok, given_scope}
    end
  end

  describe "with a resource_owner" do
    setup do
      resource_owner = %User{}
      public_scope = insert(:scope, public: true)
      private_scope = insert(:scope, public: false)
      {:ok,
        resource_owner: resource_owner,
        private_scope: private_scope,
        public_scope: public_scope
      }
    end

    test "returns an error if private scope given", %{
      resource_owner: resource_owner,
      private_scope: private_scope
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [] end)
      given_scope = Enum.join(["any", private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{resource_owner: resource_owner}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some private scope are unknown or unauthorized by the resource_owner", %{
      resource_owner: resource_owner,
      private_scope: private_scope,
      public_scope: public_scope
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [public_scope, private_scope] end)
      given_scope = Enum.join(["any", private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{resource_owner: resource_owner}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some non existing scope given", %{
      resource_owner: resource_owner
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [] end)
      given_scope = Enum.join(["any1", "any2"], " ")

      assert Scope.authorize(scope: given_scope, against: %{resource_owner: resource_owner}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns scope if some public scope given", %{
      resource_owner: resource_owner,
      public_scope: public_scope
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [] end)
      given_scope = Enum.join([public_scope.name], " ")
      authorized_scope = Scope.authorize(scope: given_scope, against: %{resource_owner: resource_owner})

      assert authorized_scope == {:ok, given_scope}
    end

    test "returns scope if some private scope are authorized by the resource_owner", %{
      resource_owner: resource_owner,
      private_scope: private_scope,
      public_scope: public_scope
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [public_scope, private_scope] end)
      given_scope = Enum.join([private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{resource_owner: resource_owner}) == {:ok, given_scope}
    end
  end

  describe "with a client and a resource owner" do
    setup do
      public_scope = insert(:scope, public: true)
      private_scope = insert(:scope, public: false)
      client_with_scope = insert(:client, authorize_scope: true, authorized_scopes: [private_scope, public_scope])
      resource_owner = %User{}
      {:ok,
        private_scope: private_scope,
        public_scope: public_scope,
        client_with_scope: client_with_scope,
        resource_owner: resource_owner
      }
    end

    test "do not duplicates scopes", %{
      public_scope: public_scope,
      private_scope: private_scope,
      client_with_scope: client,
      resource_owner: resource_owner
    } do
      ResourceOwners
      |> stub(:authorized_scopes, fn(_resource_owner) -> [public_scope, private_scope] end)
      given_scope = public_scope.name
      assert Scope.authorize(
        scope: given_scope,
        against: %{client: client, resource_owner: resource_owner}
      ) == {:ok, given_scope}
    end
  end

  describe "with a token" do
    setup do
      token = insert(:token)
      public_scope = insert(:scope, public: true)
      private_scope = insert(:scope, public: false)
      client_with_scope = insert(:client, authorize_scope: true, authorized_scopes: [private_scope, public_scope])
      token_public_scope = insert(:scope, public: true)
      token_private_scope = insert(:scope, public: false)
      token_with_scope = insert(:token, scope: Enum.join([token_private_scope.name, token_public_scope.name], " "))
      {:ok,
        token: to_oauth_schema(token),
        private_scope: to_oauth_schema(private_scope),
        public_scope: to_oauth_schema(public_scope),
        token_private_scope: to_oauth_schema(token_private_scope),
        token_public_scope: to_oauth_schema(token_public_scope),
        token_with_scope: to_oauth_schema(token_with_scope),
        client_with_scope: to_oauth_schema(client_with_scope)
      }
    end

    test "returns an error if scope given and token does not have any", %{
      token: token,
      public_scope: public_scope
    } do
      given_scope = Enum.join([public_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some private scope are unknown or unauthorized by the token", %{
      token_with_scope: token,
      private_scope: private_scope
    } do
      given_scope = Enum.join(["any", private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some non existing scope given are unknown or unauthorized by the token", %{
      token_with_scope: token
    } do
      given_scope = Enum.join(["any1", "any2"], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some non authorized by token but by client scope given", %{
      token_with_scope: token,
      client_with_scope: client
    } do
      given_scope = Enum.join([List.first(client.authorized_scopes).name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns an error if some public scope given are unknown or unauthorized by the token", %{
      token_with_scope: token,
      public_scope: public_scope
    } do
      given_scope = Enum.join([public_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {
        :error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns scope if some private scope are authorized by the token", %{
      token_with_scope: token,
      token_private_scope: private_scope
    } do
      given_scope = Enum.join([private_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {:ok, given_scope}
    end

    test "returns scope if some public scope are authorized by the token", %{
      token_with_scope: token,
      token_public_scope: public_scope
    } do
      given_scope = Enum.join([public_scope.name], " ")

      assert Scope.authorize(scope: given_scope, against: %{token: token}) == {:ok, given_scope}
    end
  end
end
