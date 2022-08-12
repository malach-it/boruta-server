defmodule BorutaIdentity.IdentityProvidersTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

  describe "identity_providers" do
    @valid_attrs %{name: "some name", type: "internal"}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil, type: "other"}

    def identity_provider_fixture(attrs \\ %{}) do
      insert(:identity_provider, Map.merge(@valid_attrs, attrs))
    end

    test "list_identity_providers/0 returns all identity_providers" do
      identity_provider = identity_provider_fixture()
      assert IdentityProviders.list_identity_providers() == [identity_provider]
    end

    test "get_identity_provider!/1 returns the identity_provider with given id" do
      identity_provider = identity_provider_fixture()
      assert IdentityProviders.get_identity_provider!(identity_provider.id) == identity_provider
    end

    test "create_identity_provider/1 with valid data creates a identity_provider" do
      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.create_identity_provider(@valid_attrs)

      assert identity_provider.name == "some name"
      assert identity_provider.type == "internal"
    end

    test "create_identity_provider/1 with valid data (with a new template) creates a identity_provider" do
      templates_attrs = %{templates: [%{type: "new_registration", content: "test content"}]}

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.create_identity_provider(Map.merge(@valid_attrs, templates_attrs))

      assert [%Template{type: "new_registration", content: "test content"}] =
               identity_provider.templates
    end

    test "create_identity_provider/1 with invalid data returns error changeset" do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  type: {"is invalid", [validation: :inclusion, enum: ["internal"]]},
                  name: {"can't be blank", [validation: :required]}
                ]
              }} = IdentityProviders.create_identity_provider(@invalid_attrs)
    end

    test "create_identity_provider/1 with invalid data (unique name) returns error changeset" do
      identity_provider_fixture()

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "identity_providers_name_index"]}
                ]
              }} = IdentityProviders.create_identity_provider(@valid_attrs)
    end

    test "update_identity_provider/2 with valid data updates the identity_provider" do
      identity_provider = identity_provider_fixture()

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.update_identity_provider(identity_provider, @update_attrs)

      assert identity_provider.name == "some updated name"
    end

    test "create_identity_provider/1 with valid data (with an existing template) creates a identity_provider" do
      identity_provider = identity_provider_fixture()
      template = insert(:template, identity_provider: identity_provider)

      templates_attrs = %{
        templates: [%{id: template.id, type: "new_registration", content: "test content"}]
      }

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.update_identity_provider(identity_provider, templates_attrs)

      template_id = template.id

      assert [
               %Template{
                 id: ^template_id,
                 type: "new_registration",
                 content: "test content"
               }
             ] = identity_provider.templates
    end

    test "create_identity_provider/1 with valid data (with an existing template, delete_if_exists) creates a identity_provider" do
      identity_provider = identity_provider_fixture()
      insert(:template, identity_provider: identity_provider)

      templates_attrs = %{
        templates: [%{type: "new_registration", content: "test content"}]
      }

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.update_identity_provider(identity_provider, templates_attrs)

      assert [
               %Template{
                 type: "new_registration",
                 content: "test content"
               }
             ] = identity_provider.templates
    end

    test "update_identity_provider/2 with invalid data returns error changeset" do
      identity_provider = identity_provider_fixture()

      assert {:error, %Ecto.Changeset{}} =
               IdentityProviders.update_identity_provider(identity_provider, @invalid_attrs)

      assert identity_provider == IdentityProviders.get_identity_provider!(identity_provider.id)
    end

    test "update_identity_provider/2 with invalid data (unique name) returns error changeset" do
      identity_provider_fixture()
      identity_provider = identity_provider_fixture(%{name: "other"})

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "identity_providers_name_index"]}
                ]
              }} = IdentityProviders.update_identity_provider(identity_provider, @valid_attrs)

      assert identity_provider == IdentityProviders.get_identity_provider!(identity_provider.id)
    end

    test "delete_identity_provider/1 deletes the identity_provider" do
      identity_provider = identity_provider_fixture()
      assert {:ok, %IdentityProvider{}} = IdentityProviders.delete_identity_provider(identity_provider)

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.get_identity_provider!(identity_provider.id)
      end
    end

    test "delete_identity_provider/1 returns an error when associated to a client" do
      identity_provider = identity_provider_fixture()
      insert(:client_identity_provider, identity_provider: identity_provider)

      assert {:error, %Ecto.Changeset{errors: [client_identity_providers: {_message, []}]}} =
               IdentityProviders.delete_identity_provider(identity_provider)
    end

    test "change_identity_provider/1 returns a identity_provider changeset" do
      identity_provider = identity_provider_fixture()
      assert %Ecto.Changeset{} = IdentityProviders.change_identity_provider(identity_provider)
    end
  end

  describe "upsert_client_identity_provider/2" do
    test "inserts client identity provider" do
      %IdentityProvider{id: identity_provider_id} = insert(:identity_provider)
      client_id = SecureRandom.uuid()

      assert {:ok,
              %ClientIdentityProvider{
                client_id: ^client_id,
                identity_provider_id: ^identity_provider_id
              }} = IdentityProviders.upsert_client_identity_provider(client_id, identity_provider_id)
    end

    test "updates client identity provider" do
      %ClientIdentityProvider{client_id: client_id} = insert(:client_identity_provider)

      %IdentityProvider{id: new_identity_provider_id} = insert(:identity_provider)

      assert {:ok,
              %ClientIdentityProvider{
                client_id: ^client_id,
                identity_provider_id: ^new_identity_provider_id
              }} = IdentityProviders.upsert_client_identity_provider(client_id, new_identity_provider_id)
    end
  end

  describe "remove_client_identity_provider/2" do
    test "remove client identity provider" do
      client_id = SecureRandom.uuid()
      client_identity_provider = insert(:client_identity_provider, client_id: client_id) |> Repo.reload()

      assert {:ok, ^client_identity_provider} = IdentityProviders.remove_client_identity_provider(client_id)

      assert_raise Ecto.NoResultsError, fn ->
        Repo.get!(ClientIdentityProvider, client_identity_provider.id)
      end
    end

    test "returns nil when not exists" do
      client_id = SecureRandom.uuid()

      assert IdentityProviders.remove_client_identity_provider(client_id) == {:ok, nil}
    end
  end

  describe "get_identity_provider_by_client_id/1" do
    test "returns nil with nil" do
      assert IdentityProviders.get_identity_provider_by_client_id(nil) == nil
    end

    test "returns nil with a raw string" do
      assert IdentityProviders.get_identity_provider_by_client_id("bad_id") == nil
    end

    test "returns nil with a random uuid" do
      assert IdentityProviders.get_identity_provider_by_client_id(SecureRandom.uuid()) == nil
    end

    test "returns client's identity provider" do
      %ClientIdentityProvider{client_id: client_id, identity_provider: identity_provider} =
        insert(:client_identity_provider)

      assert IdentityProviders.get_identity_provider_by_client_id(client_id) == identity_provider
    end
  end

  describe "get_identity_provider_template!/2" do
    test "raises an error with unexisting identity provider" do
      identity_provider_id = SecureRandom.uuid()

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.get_identity_provider_template!(identity_provider_id, :unexisting)
      end
    end

    test "raises an error with unexisting template" do
      identity_provider_id = insert(:identity_provider).id

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.get_identity_provider_template!(identity_provider_id, :unexisting)
      end
    end

    test "returns default template" do
      identity_provider = insert(:identity_provider, templates: [])

      template = IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration)

      assert template == %{
               Template.default_template(:new_registration)
               | identity_provider_id: identity_provider.id,
                 identity_provider: identity_provider,
                 layout: IdentityProvider.template(identity_provider, :layout)
             }
    end

    test "returns identity provider template with a layout" do
      template =
        build(:new_registration_template,
          content: "custom registration template"
        )

      %IdentityProvider{templates: [template]} =
        identity_provider = insert(:identity_provider, templates: [template])

      assert IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration) ==
               %{
                 template
                 | layout: IdentityProvider.template(identity_provider, :layout),
                   identity_provider: identity_provider
               }
    end
  end

  describe "upsert_template/2" do
    test "inserts with a default template" do
      identity_provider = insert(:identity_provider)
      template = IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration)

      assert {:ok, template} = IdentityProviders.upsert_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end

    test "updates with an existing template" do
      identity_provider = insert(:identity_provider)
      template = insert(:new_registration_template, identity_provider: identity_provider)

      assert {:ok, template} = IdentityProviders.upsert_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end
  end

  describe "delete_identity_provider_template!/2" do
    test "raises an error with unexisting identity provider" do
      identity_provider_id = SecureRandom.uuid()

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_identity_provider_template!(identity_provider_id, :unexisting)
      end
    end

    test "raises an error with unexisting template" do
      identity_provider_id = insert(:identity_provider).id

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_identity_provider_template!(identity_provider_id, :unexisting)
      end
    end

    test "returns an error if template is default" do
      identity_provider = insert(:identity_provider, templates: [])

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_identity_provider_template!(identity_provider.id, :new_registration)
      end
    end

    test "returns identity provider template with a layout" do
      template =
        build(:new_registration_template,
          content: "custom registration template"
        )

      %IdentityProvider{templates: [template]} =
        identity_provider = insert(:identity_provider, templates: [template])

      default_template = %{
        Template.default_template(:new_registration)
        | identity_provider_id: identity_provider.id
      }

      reseted_template =
        IdentityProviders.delete_identity_provider_template!(identity_provider.id, :new_registration)

      assert reseted_template.default == true
      assert reseted_template.type == "new_registration"
      assert reseted_template.content == default_template.content

      assert Repo.get_by(Template, id: template.id) == nil
    end
  end

  describe "backends" do
    alias BorutaIdentity.IdentityProviders.Backend

    import BorutaIdentity.IdentityProvidersFixtures

    @invalid_attrs %{name: nil, type: nil}

    test "list_backends/0 returns all backends" do
      backend = backend_fixture()
      assert IdentityProviders.list_backends() == [backend]
    end

    test "get_backend!/1 returns the backend with given id" do
      backend = backend_fixture()
      assert IdentityProviders.get_backend!(backend.id) == backend
    end

    test "create_backend/1 with valid data creates a backend" do
      valid_attrs = %{name: "some name", type: "some type"}

      assert {:ok, %Backend{} = backend} = IdentityProviders.create_backend(valid_attrs)
      assert backend.name == "some name"
      assert backend.type == "some type"
    end

    test "create_backend/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = IdentityProviders.create_backend(@invalid_attrs)
    end

    test "update_backend/2 with valid data updates the backend" do
      backend = backend_fixture()
      update_attrs = %{name: "some updated name", type: "some updated type"}

      assert {:ok, %Backend{} = backend} = IdentityProviders.update_backend(backend, update_attrs)
      assert backend.name == "some updated name"
      assert backend.type == "some updated type"
    end

    test "update_backend/2 with invalid data returns error changeset" do
      backend = backend_fixture()
      assert {:error, %Ecto.Changeset{}} = IdentityProviders.update_backend(backend, @invalid_attrs)
      assert backend == IdentityProviders.get_backend!(backend.id)
    end

    test "delete_backend/1 deletes the backend" do
      backend = backend_fixture()
      assert {:ok, %Backend{}} = IdentityProviders.delete_backend(backend)
      assert_raise Ecto.NoResultsError, fn -> IdentityProviders.get_backend!(backend.id) end
    end

    test "change_backend/1 returns a backend changeset" do
      backend = backend_fixture()
      assert %Ecto.Changeset{} = IdentityProviders.change_backend(backend)
    end
  end
end
