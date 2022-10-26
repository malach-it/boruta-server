defmodule BorutaIdentity.IdentityProvidersTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory
  import Mox

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

  setup :set_mox_global
  setup :verify_on_exit!

  describe "identity_providers" do
    setup do
      backend = insert(:backend)

      {:ok, backend: backend}
    end

    @valid_attrs %{name: "some name", backend_id: nil}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil}

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

    test "create_identity_provider/1 with valid data creates a identity_provider", %{
      backend: backend
    } do
      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.create_identity_provider(%{@valid_attrs | backend_id: backend.id})

      assert identity_provider.name == "some name"
    end

    test "create_identity_provider/1 with valid data (with a new template) creates a identity_provider",
         %{backend: backend} do
      templates_attrs = %{templates: [%{type: "new_registration", content: "test content"}]}

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.create_identity_provider(
                 Map.merge(%{@valid_attrs | backend_id: backend.id}, templates_attrs)
               )

      assert [%Template{type: "new_registration", content: "test content"}] =
               identity_provider.templates
    end

    test "create_identity_provider/1 with invalid data returns error changeset" do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name: {"can't be blank", [validation: :required]},
                  backend_id: {"can't be blank", [validation: :required]}
                ]
              }} = IdentityProviders.create_identity_provider(@invalid_attrs)
    end

    test "create_identity_provider/1 with invalid data (unique name) returns error changeset", %{
      backend: backend
    } do
      identity_provider_fixture()

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "identity_providers_name_index"]}
                ]
              }} =
               IdentityProviders.create_identity_provider(%{@valid_attrs | backend_id: backend.id})
    end

    test "update_identity_provider/2 with valid data updates the identity_provider" do
      identity_provider = identity_provider_fixture()

      assert {:ok, %IdentityProvider{} = identity_provider} =
               IdentityProviders.update_identity_provider(identity_provider, @update_attrs)

      assert identity_provider.name == "some updated name"
    end

    test "update_identity_provider/1 with valid data (with an existing template) creates a identity_provider" do
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

    test "update_identity_provider/1 with valid data (with an existing template, delete_if_exists) creates a identity_provider" do
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

    test "update_identity_provider/2 with invalid data (unique name) returns error changeset", %{
      backend: backend
    } do
      identity_provider_fixture()
      identity_provider = identity_provider_fixture(%{name: "other"})

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  name:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "identity_providers_name_index"]}
                ]
              }} =
               IdentityProviders.update_identity_provider(identity_provider, %{
                 @valid_attrs
                 | backend_id: backend.id
               })

      assert identity_provider == IdentityProviders.get_identity_provider!(identity_provider.id)
    end

    test "delete_identity_provider/1 deletes the identity_provider" do
      identity_provider = identity_provider_fixture()

      assert {:ok, %IdentityProvider{}} =
               IdentityProviders.delete_identity_provider(identity_provider)

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
              }} =
               IdentityProviders.upsert_client_identity_provider(client_id, identity_provider_id)
    end

    test "updates client identity provider" do
      %ClientIdentityProvider{client_id: client_id} = insert(:client_identity_provider)

      %IdentityProvider{id: new_identity_provider_id} = insert(:identity_provider)

      assert {:ok,
              %ClientIdentityProvider{
                client_id: ^client_id,
                identity_provider_id: ^new_identity_provider_id
              }} =
               IdentityProviders.upsert_client_identity_provider(
                 client_id,
                 new_identity_provider_id
               )
    end
  end

  describe "remove_client_identity_provider/2" do
    test "remove client identity provider" do
      client_id = SecureRandom.uuid()

      client_identity_provider =
        insert(:client_identity_provider, client_id: client_id) |> Repo.reload()

      assert {:ok, ^client_identity_provider} =
               IdentityProviders.remove_client_identity_provider(client_id)

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

      template =
        IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration)

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

      assert IdentityProviders.get_identity_provider_template!(
               identity_provider.id,
               :new_registration
             ) ==
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

      template =
        IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_registration)

      assert {:ok, template} =
               IdentityProviders.upsert_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end

    test "updates with an existing template" do
      identity_provider = insert(:identity_provider)
      template = insert(:new_registration_template, identity_provider: identity_provider)

      assert {:ok, template} =
               IdentityProviders.upsert_template(template, %{content: "new content"})

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
        IdentityProviders.delete_identity_provider_template!(
          identity_provider.id,
          :new_registration
        )
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
        IdentityProviders.delete_identity_provider_template!(
          identity_provider.id,
          :new_registration
        )

      assert reseted_template.default == true
      assert reseted_template.type == "new_registration"
      assert reseted_template.content == default_template.content

      assert Repo.get_by(Template, id: template.id) == nil
    end
  end

  describe "backends" do
    import BorutaIdentity.IdentityProvidersFixtures

    @invalid_attrs %{name: nil, type: "bad type"}

    test "list_backends/0 returns all backends" do
      backend = backend_fixture()
      assert IdentityProviders.list_backends() |> Enum.member?(backend)
    end

    test "get_backend!/1 returns the backend with given id" do
      backend = backend_fixture()
      assert IdentityProviders.get_backend!(backend.id) == backend
    end

    test "create_backend/1 with valid data creates a backend" do
      valid_attrs = %{name: "some name", type: "Elixir.BorutaIdentity.Accounts.Internal"}

      assert {:ok, %Backend{} = backend} = IdentityProviders.create_backend(valid_attrs)
      assert backend.name == "some name"
      assert backend.type == "Elixir.BorutaIdentity.Accounts.Internal"
    end

    test "create_backend/1 with valid argon2 password hashing opts creates a backend" do
      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        password_hashing_alg: "argon2",
        password_hashing_opts: %{
          "salt_len" => 16,
          "t_cost" => 8,
          "m_cost" => 16,
          "parallelism" => 2,
          "format" => "encoded",
          "hashlen" => 32,
          "argon2_type" => 2
        }
      }

      assert {:ok, %Backend{} = backend} = IdentityProviders.create_backend(valid_attrs)
      assert backend.name == "some name"
      assert backend.type == "Elixir.BorutaIdentity.Accounts.Internal"
      assert backend.password_hashing_alg == "argon2"

      assert backend.password_hashing_opts == %{
               "argon2_type" => 2,
               "format" => "encoded",
               "hashlen" => 32,
               "m_cost" => 16,
               "parallelism" => 2,
               "salt_len" => 16,
               "t_cost" => 8
             }
    end

    test "create_backend/1 with valid bcrypt password hashing opts creates a backend" do
      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        password_hashing_alg: "bcrypt",
        password_hashing_opts: %{
          "log_rounds" => 12,
          "legacy" => false
        }
      }

      assert {:ok, %Backend{} = backend} = IdentityProviders.create_backend(valid_attrs)
      assert backend.name == "some name"
      assert backend.type == "Elixir.BorutaIdentity.Accounts.Internal"
      assert backend.password_hashing_alg == "bcrypt"
      assert backend.password_hashing_opts == %{"legacy" => false, "log_rounds" => 12}
    end

    test "create_backend/1 set as default will override other backends default attribute" do
      other_backend = backend_fixture(%{is_default: true})

      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        is_default: true
      }

      assert {:ok, %Backend{} = backend} = IdentityProviders.create_backend(valid_attrs)
      assert backend.is_default
      refute Repo.reload!(other_backend).is_default
    end

    test "create_backend/1 with invalid argon2 password hashing opts returns an error changeset" do
      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        password_hashing_alg: "argon2",
        password_hashing_opts: %{
          "salt_len" => true,
          "t_cost" => true,
          "m_cost" => true,
          "parallelism" => true,
          "format" => true,
          "hashlen" => true,
          "argon2_type" => true
        }
      }

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/t_cost", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/salt_len", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/parallelism", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/m_cost", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/hashlen", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected String but got Boolean. at #/format", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/argon2_type", []}
                ]
              }} = IdentityProviders.create_backend(valid_attrs)
    end

    test "create_backend/1 with invalid pbkdf2 password hashing opts returns an error changeset" do
      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        password_hashing_alg: "pbkdf2",
        password_hashing_opts: %{
          "salt_len" => true,
          "format" => true,
          "digest" => true,
          "length" => true
        }
      }

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/salt_len", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/length", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected String but got Boolean. at #/format", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected String but got Boolean. at #/digest", []}
                ]
              }} = IdentityProviders.create_backend(valid_attrs)
    end

    test "create_backend/1 with invalid bcrypt password hashing opts returns an error changeset" do
      valid_attrs = %{
        name: "some name",
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        password_hashing_alg: "bcrypt",
        password_hashing_opts: %{
          "log_rounds" => true,
          "legacy" => "invalid"
        }
      }

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  password_hashing_opts:
                    {"Type mismatch. Expected Number but got Boolean. at #/log_rounds", []},
                  password_hashing_opts:
                    {"Type mismatch. Expected Boolean but got String. at #/legacy", []}
                ]
              }} = IdentityProviders.create_backend(valid_attrs)
    end

    test "create_backend/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = IdentityProviders.create_backend(@invalid_attrs)
    end

    test "update_backend/2 with valid data updates the backend" do
      backend = backend_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Backend{} = backend} = IdentityProviders.update_backend(backend, update_attrs)
      assert backend.name == "some updated name"
    end

    test "update_backend/2 stop associated ldap connection pool" do
      backend = insert(:ldap_backend)
      update_attrs = %{ldap_pool_size: 3}

      BorutaIdentity.LdapRepoMock
      |> stub(:open, fn host, _opts ->
        assert host == backend.ldap_host

        {:ok, SecureRandom.uuid()}
      end)

      {:ok, ldap_pool_pid} = Ldap.start_link(backend)

      assert {:ok, %Backend{}} = IdentityProviders.update_backend(backend, update_attrs)
      refute Process.alive?(ldap_pool_pid)
    end

    test "update_backend/2 cannot remove default" do
      backend = backend_fixture(%{is_default: true})
      update_attrs = %{name: "some updated name", is_default: false}

      assert {:error,
              %Ecto.Changeset{
                errors: [is_default: {"There must be at least one default backend.", []}]
              }} = IdentityProviders.update_backend(backend, update_attrs)
    end

    test "update_backend/2 other backends default attribute" do
      other_backend = backend_fixture(%{is_default: true})
      backend = backend_fixture()
      update_attrs = %{name: "some updated name", is_default: true}

      assert {:ok, %Backend{} = backend} = IdentityProviders.update_backend(backend, update_attrs)
      assert backend.is_default
      refute Repo.reload!(other_backend).is_default
    end

    test "update_backend/2 with invalid data returns error changeset" do
      backend = backend_fixture()

      assert {:error, %Ecto.Changeset{}} =
               IdentityProviders.update_backend(backend, @invalid_attrs)

      assert backend == IdentityProviders.get_backend!(backend.id)
    end

    test "delete_backend/1 deletes the backend" do
      backend = backend_fixture()
      assert {:ok, %Backend{}} = IdentityProviders.delete_backend(backend)
      assert_raise Ecto.NoResultsError, fn -> IdentityProviders.get_backend!(backend.id) end
    end

    test "delete_backend/1 can't delete a default backend" do
      assert {:error,
              %Ecto.Changeset{
                errors: [is_default: {"Deleting a default backend is prohibited.", []}]
              }} = IdentityProviders.delete_backend(Backend.default!())

      assert Backend.default!()
    end

    test "delete_backend/1 stop the associated ldap connection pool" do
      backend = insert(:ldap_backend)

      BorutaIdentity.LdapRepoMock
      |> stub(:open, fn host, _opts ->
        assert host == backend.ldap_host

        {:ok, SecureRandom.uuid()}
      end)

      {:ok, ldap_pool_pid} = Ldap.start_link(backend)

      assert {:ok, %Backend{}} = IdentityProviders.delete_backend(backend)
      refute Process.alive?(ldap_pool_pid)
      assert_raise Ecto.NoResultsError, fn -> IdentityProviders.get_backend!(backend.id) end
    end

    test "change_backend/1 returns a backend changeset" do
      backend = backend_fixture()
      assert %Ecto.Changeset{} = IdentityProviders.change_backend(backend)
    end
  end

  describe "get_backend_email_template!/2" do
    test "raises an error with unexisting identity provider" do
      backend_id = SecureRandom.uuid()

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.get_backend_email_template!(backend_id, :unexisting)
      end
    end

    test "raises an error with unexisting template" do
      backend_id = insert(:backend).id

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.get_backend_email_template!(backend_id, :unexisting)
      end
    end

    test "returns default template" do
      backend = insert(:backend, email_templates: [])

      template = IdentityProviders.get_backend_email_template!(backend.id, :reset_password_instructions)

      assert template == %{
               EmailTemplate.default_template(:reset_password_instructions)
               | backend_id: backend.id,
                 backend: backend
             }
    end

    test "returns backend email template with a layout" do
      template =
        build(:reset_password_instructions_email_template,
          txt_content: "custom reset password instructions template"
        )

      %Backend{email_templates: [template]} =
        backend = insert(:backend, email_templates: [template])

      assert IdentityProviders.get_backend_email_template!(
               backend.id,
               :reset_password_instructions
             ) ==
               %{template | backend: backend}
    end
  end

  describe "upsert_email_template/2" do
    test "inserts with a default template" do
      backend = insert(:backend)

      template = IdentityProviders.get_backend_email_template!(backend.id, :reset_password_instructions)

      assert {:ok, template} =
               IdentityProviders.upsert_email_template(template, %{txt_content: "new txt content"})

      assert Repo.reload(template)
    end

    test "updates with an existing template" do
      backend = insert(:backend)
      template = insert(:reset_password_instructions_email_template, backend: backend)

      assert {:ok, template} =
               IdentityProviders.upsert_email_template(template, %{txt_content: "new content"})

      assert Repo.reload(template)
    end
  end

  describe "delete_email_template!/2" do
    test "raises an error with unexisting identity provider" do
      backend_id = SecureRandom.uuid()

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_email_template!(backend_id, :unexisting)
      end
    end

    test "raises an error with unexisting template" do
      backend_id = insert(:backend).id

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_email_template!(backend_id, :unexisting)
      end
    end

    test "returns an error if template is default" do
      backend = insert(:backend, email_templates: [])

      assert_raise Ecto.NoResultsError, fn ->
        IdentityProviders.delete_email_template!(
          backend.id,
          :reset_password_instructions
        )
      end
    end

    test "returns identity provider template with a layout" do
      template =
        build(:reset_password_instructions_email_template,
          txt_content: "custom registration template"
        )

      %Backend{email_templates: [template]} =
        backend = insert(:backend, email_templates: [template])

      default_template = %{
        EmailTemplate.default_template(:reset_password_instructions)
        | backend_id: backend.id
      }

      reseted_template =
        IdentityProviders.delete_email_template!(
          backend.id,
          :reset_password_instructions
        )

      assert reseted_template.default == true
      assert reseted_template.type == "reset_password_instructions"
      assert reseted_template.txt_content == default_template.txt_content

      assert Repo.get_by(EmailTemplate, id: template.id) == nil
    end
  end
end
