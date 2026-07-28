defmodule BorutaIdentity.ResourceOwnersTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.ResourceOwner
  alias BorutaAuth.BlsKeyPair
  alias BorutaAuth.ClientBlsKeyPair
  alias BorutaAuth.PhiAccessToken
  alias BorutaIdentity.Accounts.UserRole
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Organizations.OrganizationUser
  alias BorutaIdentity.Repo
  alias BorutaIdentity.ResourceOwners

  doctest BorutaIdentity

  @valid_username unique_user_email()
  @valid_password valid_user_password()

  describe "get_by/1" do
    test "returns an user by username" do
      username = @valid_username

      user =
        user_fixture(%{
          email: username,
          password: @valid_password,
          backend: Backend.default!()
        })

      {:ok, result} = ResourceOwners.get_by(username: username)

      user_id = user.id

      assert %ResourceOwner{sub: ^user_id, username: ^username, extra_claims: %{user: _user}} =
               result
    end

    test "returns an user by sub" do
      user =
        user_fixture(%{
          email: @valid_username,
          password: @valid_password,
          backend: Backend.default!()
        })

      {:ok, result} = ResourceOwners.get_by(sub: user.id, scope: "")

      user_id = user.id
      user_username = user.username
      assert %ResourceOwner{sub: ^user_id, username: ^user_username} = result
    end

    test "returns nil when username do not exists" do
      user_fixture(%{
        email: @valid_username,
        password: @valid_password,
        backend: Backend.default!()
      })

      assert ResourceOwners.get_by(username: "other") == {:error, "Invalid username or password."}
    end
  end

  describe "#check_password/2" do
    test "returns ok if password match" do
      username = @valid_username
      backend = Backend.default!()

      user =
        user_fixture(%{
          email: username,
          password: @valid_password,
          backend: backend
        })

      {:ok, impl_user} =
        apply(Backend.implementation(backend), :get_user, [backend, %{email: username}])

      resource_owner = %ResourceOwner{
        sub: user.id,
        username: user.username,
        extra_claims: %{user: impl_user}
      }

      assert ResourceOwners.check_password(resource_owner, @valid_password) == :ok
    end

    test "returns an error if password do not match" do
      user =
        user_fixture(%{
          email: @valid_username,
          password: @valid_password,
          backend: Backend.default!()
        })

      resource_owner = %ResourceOwner{sub: user.id}

      assert ResourceOwners.check_password(resource_owner, "wrong password") ==
               {:error, "Invalid username or password."}
    end
  end

  describe "authorized_scopes/1" do
    test "returns an empty array" do
      user = user_fixture(%{backend: Backend.default!()})
      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.authorized_scopes(resource_owner) == []
    end

    test "return user associated scopes with authorized scopes" do
      %{id: id} = user = user_fixture(%{backend: Backend.default!()})
      {:ok, scope} = Admin.create_scope(%{name: "scope:scope"})
      insert(:user_authorized_scope, user_id: id, scope_id: scope.id)

      resource_owner = %ResourceOwner{sub: user.id}

      name = scope.name
      assert [%Boruta.Oauth.Scope{name: ^name}] = ResourceOwners.authorized_scopes(resource_owner)
    end

    test "return user associated scopes with roles" do
      %{id: id} = user = user_fixture(%{backend: Backend.default!()})
      {:ok, scope} = Admin.create_scope(%{name: "scope:scope"})
      role = insert(:role)
      insert(:role_scope, role_id: role.id, scope_id: scope.id)
      insert(:user_role, user_id: id, role_id: role.id)

      resource_owner = %ResourceOwner{sub: user.id}

      name = scope.name
      assert [%Boruta.Oauth.Scope{name: ^name}] = ResourceOwners.authorized_scopes(resource_owner)
    end
  end

  describe "claims/2" do
    test "adds one client-consented proof per disclosed metadata claim" do
      user = user_fixture()
      client = Boruta.Factory.insert(:client)
      {:ok, client_key_pair} = ClientBlsKeyPair.get_or_create(client.id)

      {:ok, backend} =
        user.backend
        |> Ecto.Changeset.change(%{
          metadata_fields: [
            %{
              "attribute_name" => "age",
              "phi_data_token" => true,
              "scopes" => ["profile"],
              "user_editable" => true
            }
          ]
        })
        |> Repo.update()

      {:ok, phi_data_token} = BlsKeyPair.phi_data_token(user.bls_public_key, "age", 42)

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{
          metadata: %{
            "age" => %{
              "value" => 42,
              "status" => "valid",
              "display" => [],
              "phi_data_token" => phi_data_token
            }
          }
        })
        |> Repo.update()

      extra_claims =
        user
        |> Map.put(:backend, backend)
        |> ResourceOwners.metadata("profile")

      claims =
        ResourceOwners.claims(
          %ResourceOwner{
            sub: user.id,
            client_id: client.id,
            extra_claims: extra_claims
          },
          "profile"
        )

      assert %{
               "_proof" => %{
                 "age" => %{
                   "phi_data_token" => ^phi_data_token,
                   "phi_access_token" => phi_access_token,
                   "resource_owner_bls_did_key" => resource_owner_did,
                   "resource_owner_key_proof" =>
                     %{
                       "value" => resource_owner_key_proof
                     } = key_proof
                 }
               }
             } = claims

      assert resource_owner_did == user.bls_did_key
      refute Map.has_key?(claims["_proof"]["age"], "client_bls_did_key")
      refute Map.has_key?(claims["_proof"]["age"], "client_key_proof")
      assert key_proof["type"] == "Bls12381G2RemainingPartyProof"

      assert PhiAccessToken.verify_remaining_proof(
               phi_access_token,
               phi_data_token,
               resource_owner_key_proof,
               client_key_pair.public_key,
               user.bls_public_key
             )

      assert PhiAccessToken.verify_with_private_keys(
               phi_access_token,
               phi_data_token,
               user.bls_private_key,
               client_key_pair.private_key
             )
    end

    test "returns user roles with profile in scope" do
      user = user_fixture()
      role = BorutaIdentity.Factory.insert(:role)

      Repo.insert(%UserRole{user_id: user.id, role_id: role.id})

      role_name = role.name

      assert %{"roles" => [^role_name]} =
               ResourceOwners.claims(%ResourceOwner{sub: user.id}, "profile")
    end

    test "returns user organizations with profile in scope" do
      user = user_fixture()
      organization = BorutaIdentity.Factory.insert(:organization)

      Repo.insert(%OrganizationUser{user_id: user.id, organization_id: organization.id})

      organization_id = organization.id
      organization_name = organization.name
      organization_label = organization.label

      assert %{
               "organizations" => [
                 %{
                   "id" => ^organization_id,
                   "name" => ^organization_name,
                   "label" => ^organization_label
                 }
               ]
             } = ResourceOwners.claims(%ResourceOwner{sub: user.id}, "profile")
    end
  end

  describe "metadata/2" do
    test "returns user metadata" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [%{"attribute_name" => "metadata"}]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"metadata" => "true"}}) |> Repo.update()

      assert %{"metadata" => "true"} = ResourceOwners.metadata(user, "")
    end

    test "filters user metadata" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [%{"attribute_name" => "metadata"}]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"filtered" => "true", "metadata" => "true"}})
        |> Repo.update()

      assert %{"metadata" => "true"} = ResourceOwners.metadata(user, "")
    end

    test "filters user metadata according to scopes" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [
            %{"attribute_name" => "without_scopes"},
            %{"attribute_name" => "test_scope", "scopes" => ["test"]},
            %{"attribute_name" => "other_scope", "scopes" => ["other"]}
          ]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{
          metadata: %{"without_scopes" => "true", "test_scope" => "true", "other_scope" => "true"}
        })
        |> Repo.update()

      assert %{"without_scopes" => "true", "test_scope" => "true"} =
               ResourceOwners.metadata(user, "test")
    end
  end
end
