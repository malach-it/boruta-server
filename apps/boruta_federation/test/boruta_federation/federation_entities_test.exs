defmodule BorutaFederation.FederationEntitiesTest do
  use BorutaFederation.DataCase, async: true

  import BorutaFederation.Factory

  alias BorutaFederation.FederationEntities
  alias BorutaFederation.FederationEntities.Entity
  alias BorutaFederation.FederationEntities.FederationEntity
  alias BorutaFederation.Repo

  @entity_valid_attrs %{
    organization_name: "test",
  }

  describe "create_entity/1" do
    test "returns an error with invalid params" do
      params = %{
        organization_name: nil,
        type: nil,
        key_pair_type: nil
      }

      assert {:error,
                %Ecto.Changeset{
                  errors: [
                    organization_name: {"can't be blank", [validation: :required]},
                    type: {"can't be blank", [validation: :required]},
                    public_key: {"can't be blank", [validation: :required]},
                    private_key: {"private_key_type is invalid", []},
                    key_pair_type:
                      {"validation failed: The type at # `null` do not match the required types [\"object\"].",
                       []}
                  ]
                }} = FederationEntities.create_entity(params)

    end

    test "creates an entity" do
      type = Atom.to_string(Entity)

      assert {:ok, %FederationEntity{
        organization_name: "test",
        type: ^type,
        public_key: pem_public_key,
        private_key: pem_private_key
      }} = FederationEntities.create_entity(@entity_valid_attrs)
      assert %{"kty" => "RSA"} = JOSE.JWK.from_pem(pem_private_key) |> JOSE.JWK.to_map() |> elem(1)
      assert %{"kty" => "RSA"} = JOSE.JWK.from_pem(pem_public_key) |> JOSE.JWK.to_map() |> elem(1)
    end

    test "returns an error with key pair not matching JWT alg" do
      assert {:error, %Ecto.Changeset{errors: errors}} =
        FederationEntities.create_entity(Map.put(@entity_valid_attrs, :key_pair_type, %{
          "type" => "oct"
        }))
      assert errors == [
        {:public_key, {"can't be blank", [validation: :required]}},
        {:private_key, {"private_key_type is invalid", []}},
        {:key_pair_type, {"validation failed: #/type do match required pattern /^ec|rsa/.", []}}
      ]
    end

    test "returns an error with an invalid key pair" do
      assert {:error, %Ecto.Changeset{errors: errors}} =
        FederationEntities.create_entity(Map.put(@entity_valid_attrs, :key_pair_type, %{
          "type" => "oct"
        }))
      assert errors == [
        {:public_key, {"can't be blank", [validation: :required]}},
        {:private_key, {"private_key_type is invalid", []}},
        {:key_pair_type, {"validation failed: #/type do match required pattern /^ec|rsa/.", []}}
      ]
    end

    test "returns an error with an invalid key pair configuration" do
      assert {:error, %Ecto.Changeset{errors: errors}} =
        FederationEntities.create_entity(Map.put(@entity_valid_attrs, :key_pair_type, %{
          "type" => "ec"
        }))
      assert errors == [
        {:public_key, {"can't be blank", [validation: :required]}},
        {:private_key, {"private_key_type is invalid", []}}
      ]
    end

    test "creates an entity with key pair type" do
      assert {:ok, %FederationEntity{public_key: pem_public_key, private_key: pem_private_key}} =
        FederationEntities.create_entity(Map.put(@entity_valid_attrs, :key_pair_type, %{
          "type" => "ec",
          "curve" => "P-256"
        }))
      assert %{"kty" => "EC"} = JOSE.JWK.from_pem(pem_private_key) |> JOSE.JWK.to_map() |> elem(1)
      assert %{"kty" => "EC"} = JOSE.JWK.from_pem(pem_public_key) |> JOSE.JWK.to_map() |> elem(1)
    end
  end

  describe "list_entities/0" do
    test "returns an empty list" do
      assert FederationEntities.list_entities() == []
    end

    test "returns entities" do
      a = insert(:entity)
      b = insert(:entity)

      result = FederationEntities.list_entities()

      assert Enum.count(result) == 2
      assert Enum.member?(result, a)
      assert Enum.member?(result, b)
    end
  end

  @tag :skip
  test "upsert_client_federation_entity/2"

  @tag :skip
  test "get_federation_entity_by_client_id/1"

  @tag :skip
  test "get_entity/1"

  @tag :skip
  test "delete_entity/1"

  describe "create_example_tree/2" do
    test "creates the entities" do
      FederationEntities.create_example_tree()
      assert Repo.all(FederationEntity) |> Enum.count() == 10
    end
  end
end
