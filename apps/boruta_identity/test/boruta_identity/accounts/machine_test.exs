defmodule BorutaIdentity.Accounts.MachineTest do
  use BorutaIdentity.DataCase

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid.VerifiablePresentations
  alias BorutaIdentity.Accounts.Machine
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.ResourceOwners

  describe "domain_user!/2" do
    test "creates a machine user from a did generated from the resource owner id_token jwk" do
      backend = insert(:backend)
      id_token = id_token_fixture("did:example:machine", %{"machine_name" => "machine"})

      assert {:ok, %User{} = user} =
               Machine.domain_user!(%ResourceOwner{sub: id_token}, backend)

      machine_did = machine_did()

      assert user.id
      assert user.uid == machine_did
      assert user.username == machine_did()
      assert user.account_type == Machine.account_type()
      assert user.backend_id == backend.id
      assert user.metadata == %{}
    end

    test "creates a machine user without an id_token sub claim" do
      backend = insert(:backend)
      id_token = id_token_fixture_without_sub(%{"machine_name" => "machine"})

      assert {:ok, %User{} = user} =
               Machine.domain_user!(%ResourceOwner{sub: id_token}, backend)

      machine_did = machine_did()

      assert user.uid == machine_did
      assert user.username == machine_did
      assert user.metadata == %{}
    end

    test "upserts a machine user by backend and generated did" do
      backend = insert(:backend)
      id_token = id_token_fixture("did:example:machine", %{"machine_name" => "machine"})

      updated_id_token =
        id_token_fixture("did:example:updated-machine", %{"machine_name" => "updated-machine"})

      assert {:ok, %User{id: user_id}} =
               Machine.domain_user!(%ResourceOwner{sub: id_token}, backend)

      assert {:ok, %User{id: ^user_id} = user} =
               Machine.domain_user!(%ResourceOwner{sub: updated_id_token}, backend)

      assert user.username == machine_did()
      assert user.metadata == %{}

      machine_did = machine_did()

      assert Repo.aggregate(
               from(u in User,
                 where:
                   u.backend_id == ^backend.id and u.uid == ^machine_did and
                     u.account_type == ^Machine.account_type()
               ),
               :count
             ) == 1
    end

    test "returns an error when id_token is invalid" do
      backend = insert(:backend)

      assert {:error, _reason} = Machine.domain_user!(%ResourceOwner{sub: "invalid"}, backend)
    end
  end

  describe "ResourceOwners.get_by/1" do
    test "stores a machine user and returns it as resource owner" do
      id_token = id_token_fixture("did:example:resource-owner")

      assert {:ok, %ResourceOwner{} = resource_owner} =
               ResourceOwners.get_by(id_token: id_token, scope: "")

      machine_did = machine_did()

      assert %User{} = user = Repo.get!(User, resource_owner.sub)
      assert user.uid == machine_did
      assert user.account_type == Machine.account_type()
      assert user.backend_id == Backend.default!().id
    end
  end

  defp id_token_fixture(sub, claims \\ %{}) do
    claims
    |> Map.put("sub", sub)
    |> sign_id_token()
  end

  defp id_token_fixture_without_sub(claims) do
    sign_id_token(claims)
  end

  defp machine_did do
    {:ok, did, _jwk} = Boruta.Did.create("key", public_jwk_fixture())

    did
  end

  defp sign_id_token(claims) do
    signer =
      Joken.Signer.create("RS256", %{"pem" => private_key_fixture()}, %{
        "jwk" => public_jwk_fixture(),
        "typ" => "openid4vci-proof+jwt"
      })

    {:ok, id_token, _claims} =
      VerifiablePresentations.Token.generate_and_sign(claims, signer)

    id_token
  end

  defp public_jwk_fixture do
    {_, public_jwk} =
      private_key_fixture()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()

    public_jwk
  end

  defp private_key_fixture do
    "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA1PaP/gbXix5itjRCaegvI/B3aFOeoxlwPPLvfLHGA4QfDmVO\nf8cU8OuZFAYzLArW3PnnwWWy39nVJOx42QRVGCGdUCmV7shDHRsr86+2DlL7pwUa\n9QyHsTj84fAJn2Fv9h9mqrIvUzAtEYRlGFvjVTGCwzEullpsB0GJafopUTFby8Wd\nSq3dGLJBB1r+Q8QtZnAxxvolhwOmYkBkkidefmm48X7hFXL2cSJm2G7wQyinOey/\nU8xDZ68mgTakiqS2RtjnFD0dnpBl5CYTe4s6oZKEyFiFNiW4KkR1GVjsKwY9oC2t\npyQ0AEUMvk9T9VdIltSIiAvOKlwFzL49cgwZDwIDAQABAoIBAG0dg/upL8k1IWiv\n8BNphrXIYLYQmiiBQTPJWZGvWIC2sl7i40yvCXjDjiRnZNK9HwgL94XtALCXYRFR\nJD41bRA3MO5A0HSPIWwJXwS10/cU56HVCNHjwKa6Rz/QiG2kNASMZEMzlvHtrjna\ndx36/sjI3HH8gh1BaTZyiuDE72SMkPbL838jfL1YY9uJ0u6hWFDbdn3sqPfJ6Cnz\n1cu0piT35nkilnIGCNYA0i3lyMeo4XrdXaAJdN9nnqbCi5ewQWqaHbrIIY5LTgzJ\nYlOr3IiecyokFxHCbULXle60u0KqXYgBHmlQJJr1Dj4c9AkQmefjC2jRMlhOrIzo\nIkIUeMECgYEA+MNLB+w6vv1ogqzM3M1OLt6bziWJCn+XkziuMrCiY9KeDD+S70+E\nhfbhM5RjCE3wxC/k59039laT973BmdMHxrDd2zSjOFmCIORv5yrD5oBHMaMZcwuQ\n45Xisi4aoQoOhyznSnjo/RjeQB7qEDzXFznLLNT79HzqyAtCWD3UIu8CgYEA2yik\n9FKl7HJEY94D2K6vNh1AHGnkwIQC72pXzlUrVuwQYngj6/Gkhw8ayFBApHfwVCXj\no9rDYPdNrrAs0Zz0JsiJp6bOCEKCrMYE16UiejUUAg/OZ5eg6+3m3/iWatkzLUuK\n1LIkVBJlEyY0uPuAaBF0V0VleNvfCGhVYOn46+ECgYAUD4OsduNh5YOZDiBTKgdF\nBlSgMiyz+QgbKjX6Bn6B+EkgibvqqonwV7FffHbkA40H9SjLfe52YhL6poXHRtpY\nroillcAX2jgBOQrBJJS5sNyM5y81NNiRUdP/NHKXS/1R71ATlF6NkoTRvOx5NL7P\ns6xryB0tYSl5ylamUQ4bZwKBgHF6FB9mA//wErVbKcayfIqajq2nrwh30kVBXQG7\nW9uAE+PIrWDoF/bOvWFnHHGMoOYRUFNxXKUCqDiBhFNs34aNY6lpV1kzhxIK3ksC\neF2qyhdfM9Kz0mEXJ+pkfw4INNWJPfNv4hueArPtnnMB1rUMBJ+DkU0JG+zwiPTL\ncVZBAoGBAM6kOsh5KGn3aI83g9ZO0TrKLXXFotxJt31Wu11ydj9K33/Qj3UXcxd4\nJPXr600F0DkLeUKBob6BALeHFWcrSz5FGLGRqdRxdv+L6g18WH5m2xEs7o6M6e5I\nIhyUC60ZewJ2M8rV4KgCJJdZE2kENlSgjU92IDVPT9Oetrc7hQJd\n-----END RSA PRIVATE KEY-----\n\n"
  end
end
