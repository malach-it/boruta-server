defmodule BorutaIdentity.RelyingPartiesTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.ClientRelyingParty
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentity.Repo

  describe "relying_parties" do
    @valid_attrs %{name: "some name", type: "internal"}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil, type: "other"}

    def relying_party_fixture(attrs \\ %{}) do
      insert(:relying_party, Map.merge(@valid_attrs, attrs))
    end

    test "list_relying_parties/0 returns all relying_parties" do
      relying_party = relying_party_fixture()
      assert RelyingParties.list_relying_parties() == [relying_party]
    end

    test "get_relying_party!/1 returns the relying_party with given id" do
      relying_party = relying_party_fixture()
      assert RelyingParties.get_relying_party!(relying_party.id) == relying_party
    end

    test "create_relying_party/1 with valid data creates a relying_party" do
      assert {:ok, %RelyingParty{} = relying_party} =
               RelyingParties.create_relying_party(@valid_attrs)

      assert relying_party.name == "some name"
      assert relying_party.type == "internal"
    end

    test "create_relying_party/1 with valid data (with a new template) creates a relying_party" do
      templates_attrs = %{templates: [%{type: "new_registration", content: "test content"}]}

      assert {:ok, %RelyingParty{} = relying_party} =
               RelyingParties.create_relying_party(Map.merge(@valid_attrs, templates_attrs))

      assert [%Template{type: "new_registration", content: "test content"}] =
               relying_party.templates
    end

    test "create_relying_party/1 with invalid data returns error changeset" do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  type: {"is invalid", [validation: :inclusion, enum: ["internal"]]},
                  name: {"can't be blank", [validation: :required]}
                ]
              }} = RelyingParties.create_relying_party(@invalid_attrs)
    end

    test "create_relying_party/1 with invalid data (unique name) returns error changeset" do
      relying_party_fixture()

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "relying_parties_name_index"]}
                ]
              }} = RelyingParties.create_relying_party(@valid_attrs)
    end

    test "update_relying_party/2 with valid data updates the relying_party" do
      relying_party = relying_party_fixture()

      assert {:ok, %RelyingParty{} = relying_party} =
               RelyingParties.update_relying_party(relying_party, @update_attrs)

      assert relying_party.name == "some updated name"
    end

    test "create_relying_party/1 with valid data (with an existing template) creates a relying_party" do
      relying_party = relying_party_fixture()
      template = insert(:template, relying_party: relying_party)

      templates_attrs = %{
        templates: [%{id: template.id, type: "new_registration", content: "test content"}]
      }

      assert {:ok, %RelyingParty{} = relying_party} =
               RelyingParties.update_relying_party(relying_party, templates_attrs)

      template_id = template.id

      assert [
               %Template{
                 id: ^template_id,
                 type: "new_registration",
                 content: "test content"
               }
             ] = relying_party.templates
    end

    test "create_relying_party/1 with valid data (with an existing template, delete_if_exists) creates a relying_party" do
      relying_party = relying_party_fixture()
      insert(:template, relying_party: relying_party)

      templates_attrs = %{
        templates: [%{type: "new_registration", content: "test content"}]
      }

      assert {:ok, %RelyingParty{} = relying_party} =
               RelyingParties.update_relying_party(relying_party, templates_attrs)

      assert [
               %Template{
                 type: "new_registration",
                 content: "test content"
               }
             ] = relying_party.templates
    end

    test "update_relying_party/2 with invalid data returns error changeset" do
      relying_party = relying_party_fixture()

      assert {:error, %Ecto.Changeset{}} =
               RelyingParties.update_relying_party(relying_party, @invalid_attrs)

      assert relying_party == RelyingParties.get_relying_party!(relying_party.id)
    end

    test "update_relying_party/2 with invalid data (unique name) returns error changeset" do
      relying_party_fixture()
      relying_party = relying_party_fixture(%{name: "other"})

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "relying_parties_name_index"]}
                ]
              }} = RelyingParties.update_relying_party(relying_party, @valid_attrs)

      assert relying_party == RelyingParties.get_relying_party!(relying_party.id)
    end

    test "delete_relying_party/1 deletes the relying_party" do
      relying_party = relying_party_fixture()
      assert {:ok, %RelyingParty{}} = RelyingParties.delete_relying_party(relying_party)

      assert_raise Ecto.NoResultsError, fn ->
        RelyingParties.get_relying_party!(relying_party.id)
      end
    end

    test "delete_relying_party/1 returns an error when associated to a client" do
      relying_party = relying_party_fixture()
      insert(:client_relying_party, relying_party: relying_party)

      assert {:error, %Ecto.Changeset{errors: [client_relying_parties: {_message, []}]}} =
               RelyingParties.delete_relying_party(relying_party)
    end

    test "change_relying_party/1 returns a relying_party changeset" do
      relying_party = relying_party_fixture()
      assert %Ecto.Changeset{} = RelyingParties.change_relying_party(relying_party)
    end
  end

  describe "upsert_client_relying_party/2" do
    test "inserts client relying party" do
      %RelyingParty{id: relying_party_id} = insert(:relying_party)
      client_id = SecureRandom.uuid()

      assert {:ok,
              %ClientRelyingParty{
                client_id: ^client_id,
                relying_party_id: ^relying_party_id
              }} = RelyingParties.upsert_client_relying_party(client_id, relying_party_id)
    end

    test "updates client relying party" do
      %ClientRelyingParty{client_id: client_id} = insert(:client_relying_party)

      %RelyingParty{id: new_relying_party_id} = insert(:relying_party)

      assert {:ok,
              %ClientRelyingParty{
                client_id: ^client_id,
                relying_party_id: ^new_relying_party_id
              }} = RelyingParties.upsert_client_relying_party(client_id, new_relying_party_id)
    end
  end

  describe "get_relying_party_by_client_id/1" do
    test "returns nil with nil" do
      assert RelyingParties.get_relying_party_by_client_id(nil) == nil
    end

    test "returns nil with a raw string" do
      assert RelyingParties.get_relying_party_by_client_id("bad_id") == nil
    end

    test "returns nil with a random uuid" do
      assert RelyingParties.get_relying_party_by_client_id(SecureRandom.uuid()) == nil
    end

    test "returns client's relying party" do
      %ClientRelyingParty{client_id: client_id, relying_party: relying_party} =
        insert(:client_relying_party)

      assert RelyingParties.get_relying_party_by_client_id(client_id) == relying_party
    end
  end

  describe "get_relying_party_template!/2" do
    test "raises an error with unexisting relying party" do
      relying_party_id = SecureRandom.uuid()

      assert_raise Ecto.NoResultsError, fn ->
        RelyingParties.get_relying_party_template!(relying_party_id, :unexisting)
      end
    end

    test "raises an error with unexisting template" do
      relying_party_id = insert(:relying_party).id

      assert_raise Ecto.NoResultsError, fn ->
        RelyingParties.get_relying_party_template!(relying_party_id, :unexisting)
      end
    end

    test "returns default template" do
      relying_party_id = insert(:relying_party).id

      template = RelyingParties.get_relying_party_template!(relying_party_id, :new_registration)

      assert template == %{
               Template.default_template(:new_registration)
               | relying_party_id: relying_party_id
             }
    end

    test "returns relying party template" do
      relying_party = insert(:relying_party)

      template =
        insert(:new_registration_template,
          content: "custom registration template",
          relying_party: relying_party
        )
        |> Repo.reload()

      assert RelyingParties.get_relying_party_template!(relying_party.id, :new_registration) ==
               template
    end
  end

  describe "upsert_template/2" do
    test "inserts with a default template" do
      relying_party = insert(:relying_party)
      template = RelyingParties.get_relying_party_template!(relying_party.id, :new_registration)

      assert {:ok, template} = RelyingParties.upsert_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end

    test "updates with an existing template" do
      relying_party = insert(:relying_party)
      template = insert(:new_registration_template, relying_party: relying_party)

      assert {:ok, template} = RelyingParties.upsert_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end
  end
end
