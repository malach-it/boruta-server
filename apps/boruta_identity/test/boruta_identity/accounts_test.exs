defmodule BorutaIdentity.AccountsTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory
  import Mox

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.ResetPasswordError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.SettingsError
  alias BorutaIdentity.Accounts.{User, UserToken}
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

  setup :set_mox_from_context

  defmodule DummyRegistration do
    @behaviour Accounts.RegistrationApplication

    @impl Accounts.RegistrationApplication
    def registration_initialized(context, template) do
      {:registration_initialized, context, template}
    end

    @impl Accounts.RegistrationApplication
    def user_registered(context, user, session_token) do
      {:user_registered, context, user, session_token}
    end

    @impl Accounts.RegistrationApplication
    def registration_failure(context, error) do
      {:registration_failure, context, error}
    end
  end

  defmodule DummySession do
    @behaviour Accounts.SessionApplication

    @impl Accounts.SessionApplication
    def session_initialized(context, template) do
      {:session_initialized, context, template}
    end

    @impl Accounts.SessionApplication
    def user_authenticated(context, user, session_token) do
      {:user_authenticated, context, user, session_token}
    end

    @impl Accounts.SessionApplication
    def authentication_failure(context, error) do
      {:authentication_failure, context, error}
    end

    @impl Accounts.SessionApplication
    def session_deleted(context) do
      {:session_deleted, context}
    end
  end

  defmodule DummyConfirmation do
    @behaviour Accounts.ConfirmationApplication

    @impl Accounts.ConfirmationApplication
    def confirmation_instructions_initialized(context, template) do
      {:confirmation_instructions_initialized, context, template}
    end

    @impl Accounts.ConfirmationApplication
    def confirmation_instructions_delivered(context) do
      {:confirmation_instructions_delivered, context}
    end

    @impl Accounts.ConfirmationApplication
    def user_confirmed(context, user) do
      {:user_confirmed, context, user}
    end

    @impl Accounts.ConfirmationApplication
    def user_confirmation_failure(context, error) do
      {:user_confirmation_failure, context, error}
    end
  end

  defmodule DummySettings do
    @behaviour Accounts.SettingsApplication

    @impl Accounts.SettingsApplication
    def edit_user_initialized(context, user, template) do
      {:edit_user_initialized, context, user, template}
    end

    @impl Accounts.SettingsApplication
    def user_updated(context, user) do
      {:user_updated, context, user}
    end

    @impl Accounts.SettingsApplication
    def user_update_failure(context, error) do
      {:user_update_failure, context, error}
    end
  end

  defmodule DummyResetPasswords do
    @behaviour Accounts.ResetPasswordApplication

    @impl Accounts.ResetPasswordApplication
    def password_instructions_initialized(context, template) do
      {:password_instructions_initialized, context, template}
    end

    @impl Accounts.ResetPasswordApplication
    def reset_password_instructions_delivered(context) do
      {:reset_password_instructions_delivered, context}
    end

    @impl Accounts.ResetPasswordApplication
    def password_reset_initialized(context, token, template) do
      {:passsword_reseet_initialized, context, token, template}
    end

    @impl Accounts.ResetPasswordApplication
    def password_reseted(context, user) do
      {:password_reseted, context, user}
    end

    @impl Accounts.ResetPasswordApplication
    def password_reset_failure(context, error) do
      {:password_reset_failure, context, error}
    end
  end

  describe "Utils.client_identity_provider/1" do
    test "returns an error when client_id is nil" do
      client_id = nil

      assert Accounts.Utils.client_identity_provider(client_id) ==
               {:error, "Client identifier not provided."}
    end

    test "returns an error when client_id is unknown" do
      client_id = SecureRandom.uuid()

      assert Accounts.Utils.client_identity_provider(client_id) ==
               {:error,
                "identity provider not configured for given OAuth client. " <>
                  "Please contact your administrator."}
    end

    test "returns client identity_provider" do
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider)

      %ClientIdentityProvider{client_id: client_id} =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider: identity_provider
        )

      identity_provider = Repo.preload(identity_provider, backend: :email_templates)

      assert Accounts.Utils.client_identity_provider(client_id) == {:ok, identity_provider}
    end
  end

  describe "initialize_registration/3" do
    setup do
      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              registrable: true
            )
        )

      {:ok, client_id: client_identity_provider.client_id}
    end

    test "returns an error with nil client_id" do
      client_id = nil
      context = :context

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.initialize_registration(context, client_id, DummyRegistration)
      end
    end

    test "returns an error with unknown client_id" do
      client_id = SecureRandom.uuid()
      context = :context

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.initialize_registration(context, client_id, DummyRegistration)
                   end
    end

    test "returns an error if registration is not enabled for client identity provider" do
      %ClientIdentityProvider{client_id: client_id} = insert(:client_identity_provider)

      context = :context

      assert_raise IdentityProviderError,
                   "Feature is not enabled for client identity provider.",
                   fn ->
                     Accounts.initialize_registration(context, client_id, DummyRegistration)
                   end
    end

    test "returns a template", %{client_id: client_id} do
      context = :context

      assert {:registration_initialized, ^context, %Template{}} =
               Accounts.initialize_registration(context, client_id, DummyRegistration)
    end
  end

  describe "register/3" do
    setup do
      identity_provider = insert(:identity_provider, registrable: true)

      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider: identity_provider
        )

      {:ok, client_id: client_identity_provider.client_id, backend: identity_provider.backend}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      user_params = %{}
      confirmation_callback_fun = & &1

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.register(
          context,
          client_id,
          user_params,
          confirmation_callback_fun,
          DummyRegistration
        )
      end
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      user_params = %{}
      confirmation_callback_fun = & &1

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.register(
                       context,
                       client_id,
                       user_params,
                       confirmation_callback_fun,
                       DummyRegistration
                     )
                   end
    end

    test "returns an error if registrations is disabled for client identity provider" do
      %ClientIdentityProvider{client_id: client_id} = insert(:client_identity_provider)
      context = :context
      user_params = %{}
      confirmation_callback_fun = & &1

      assert_raise IdentityProviderError,
                   "Feature is not enabled for client identity provider.",
                   fn ->
                     Accounts.register(
                       context,
                       client_id,
                       user_params,
                       confirmation_callback_fun,
                       DummyRegistration
                     )
                   end
    end

    test "returns a template on error", %{client_id: client_id} do
      context = :context
      user_params = %{}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{template: %Template{}}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )
    end

    test "requires email and password to be set", %{client_id: client_id} do
      context = :context
      user_params = %{}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{changeset: changeset}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given", %{client_id: client_id} do
      context = :context
      user_params = %{email: "not valid", password: "not valid"}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{changeset: changeset}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security", %{client_id: client_id} do
      too_long = String.duplicate("too_long", 100)
      context = :context
      user_params = %{email: too_long, password: too_long}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{changeset: changeset}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness", %{client_id: client_id} do
      %{username: email} = user_fixture()
      context = :context
      user_params = %{email: email}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{changeset: changeset}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      user_params = %{email: String.upcase(email)}
      confirmation_callback_fun = & &1

      assert {:registration_failure, ^context, %RegistrationError{changeset: changeset}} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password", %{client_id: client_id} do
      email = unique_user_email()
      context = :context
      user_params = %{email: email, password: valid_user_password()}
      confirmation_callback_fun = & &1

      assert {:user_registered, ^context, user, session_token} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert session_token
      assert user.username == email
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "registers users with metadata", %{client_id: client_id, backend: backend} do
      {:ok, _backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [
            %{"attribute_name" => "test", "user_editable" => true},
            %{"attribute_name" => "restricted_field", "user_editable" => false}
          ]
        })
        |> Repo.update()

      metadata = %{"test" => "test value"}
      email = unique_user_email()
      context = :context

      user_params = %{
        email: email,
        password: valid_user_password(),
        metadata: Map.put(metadata, "restricted_field", "restricted")
      }

      confirmation_callback_fun = & &1

      assert {:user_registered, ^context, user, _session_token} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert user.metadata == %{
               "test" => %{"value" => "test value", "status" => "valid", "display" => []}
             }
    end

    test "registers users with default organization", %{client_id: client_id, backend: backend} do
      {:ok, _backend} =
        Ecto.Changeset.change(backend, %{create_default_organization: true}) |> Repo.update()

      email = unique_user_email()
      context = :context

      user_params = %{
        email: email,
        password: valid_user_password()
      }

      confirmation_callback_fun = & &1

      assert {:user_registered, ^context, %User{organizations: [organization], uid: uid},
              _session_token} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      new_organization_name = "default_#{uid}"

      assert %{organization: %{name: ^new_organization_name}} =
               Repo.preload(organization, :organization)
    end

    @tag :skip
    test "delivers a confirmation mail when identity provider confirmable"

    @tag :skip
    test "does not deliver a confirmation mail when identity provider not confirmable"
  end

  describe "initialize_session/3" do
    setup do
      client_identity_provider = BorutaIdentity.Factory.insert(:client_identity_provider)

      {:ok, client_id: client_identity_provider.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.initialize_session(
          context,
          client_id,
          DummySession
        )
      end
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.initialize_session(
                       context,
                       client_id,
                       DummySession
                     )
                   end
    end

    test "returns identity provider and a template", %{client_id: client_id} do
      context = :context

      assert {:session_initialized, ^context, %Template{type: "new_session"}} =
               Accounts.initialize_session(
                 context,
                 client_id,
                 DummySession
               )
    end
  end

  describe "create_session/4 with an internal backend" do
    setup do
      confirmable_client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: insert(:identity_provider, confirmable: true)
        )

      no_password_client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: insert(:identity_provider, check_password: false)
        )

      client_identity_provider = BorutaIdentity.Factory.insert(:client_identity_provider)

      {:ok,
       backend: client_identity_provider.identity_provider.backend,
       client_id: client_identity_provider.client_id,
       confirmable_backend: confirmable_client_identity_provider.identity_provider.backend,
       confirmable_client_id: confirmable_client_identity_provider.client_id,
       no_password_backend: no_password_client_identity_provider.identity_provider.backend,
       no_password_client_id: no_password_client_identity_provider.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      authentication_params = %{}

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.create_session(
          context,
          client_id,
          authentication_params,
          DummySession
        )
      end
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      authentication_params = %{}

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.create_session(
                       context,
                       client_id,
                       authentication_params,
                       DummySession
                     )
                   end
    end

    test "returns an error with empty email", %{client_id: client_id} do
      context = :context
      authentication_params = %{email: ""}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong email", %{client_id: client_id} do
      context = :context
      authentication_params = %{email: "does_not_exist"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error without password", %{client_id: client_id} do
      %Internal.User{email: email} = insert(:internal_user)
      context = :context
      authentication_params = %{email: email}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong password", %{client_id: client_id} do
      %Internal.User{email: email} = insert(:internal_user)
      context = :context
      authentication_params = %{email: email, password: "wrong password"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong password (confirmable)", %{
      confirmable_client_id: client_id
    } do
      %Internal.User{email: email} = insert(:internal_user)
      context = :context
      authentication_params = %{email: email, password: "wrong password"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error if not confirmed", %{
      confirmable_backend: backend,
      confirmable_client_id: client_id
    } do
      %Internal.User{email: email} = insert(:internal_user, backend: backend)
      context = :context
      authentication_params = %{email: email, password: valid_user_password()}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_confirmation_instructions"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Email confirmation is required to authenticate."
    end

    test "authenticates the user", %{client_id: client_id, backend: backend} do
      %Internal.User{id: uid, email: username} = insert(:internal_user, backend: backend)
      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      assert {:user_authenticated, ^context,
              %User{
                username: ^username,
                backend: ^backend,
                uid: ^uid,
                last_login_at: last_login_at
              },
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert last_login_at
      assert session_token
    end

    test "authenticates the user with no password", %{no_password_client_id: client_id, no_password_backend: backend} do
      context = :context
      username = "no_password@test.test"
      authentication_params = %{email: username}

      assert {:user_authenticated, ^context,
              %User{
                username: ^username,
                backend: ^backend,
                last_login_at: last_login_at
              },
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert last_login_at
      assert session_token
    end

    test "does not create multiple users accross multiple authentications", %{
      client_id: client_id,
      backend: backend
    } do
      %Internal.User{id: uid, email: username} = insert(:internal_user, backend: backend)
      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      assert {:user_authenticated, ^context,
              %User{id: user_id, username: ^username, backend: ^backend, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token

      assert {:user_authenticated, ^context,
              %User{id: new_user_id, username: ^username, backend: ^backend, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token
      assert user_id == new_user_id
    end

    @tag :skip
    test "returns a valid session token"
  end

  describe "create_session/4 with a ldap backend" do
    setup do
      backend = insert(:ldap_backend)

      confirmable_client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: insert(:identity_provider, confirmable: true, backend: backend)
        )

      client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: insert(:identity_provider, backend: backend)
        )

      BorutaIdentity.LdapRepoMock
      |> stub(:open, fn host, _opts ->
        assert host == backend.ldap_host

        {:ok, :ldap_pid}
      end)
      |> stub(:close, fn _handle ->
        :ok
      end)

      {:ok,
       backend: backend,
       client_id: client_identity_provider.client_id,
       confirmable_backend: confirmable_client_identity_provider.identity_provider.backend,
       confirmable_client_id: confirmable_client_identity_provider.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      authentication_params = %{}

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.create_session(
          context,
          client_id,
          authentication_params,
          DummySession
        )
      end
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      authentication_params = %{}

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.create_session(
                       context,
                       client_id,
                       authentication_params,
                       DummySession
                     )
                   end
    end

    test "returns an error with empty email", %{client_id: client_id} do
      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        assert email == ""

        {:error, "user not found"}
      end)

      context = :context
      authentication_params = %{email: ""}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong email", %{client_id: client_id} do
      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        assert email == "does_not_exist"

        {:error, "user not found"}
      end)

      context = :context
      authentication_params = %{email: "does_not_exist"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error without password", %{client_id: client_id} do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == nil

        {:error, :boom}
      end)

      context = :context
      authentication_params = %{email: username}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong password", %{client_id: client_id} do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == "wrong password"

        {:error, :boom}
      end)

      context = :context
      authentication_params = %{email: username, password: "wrong password"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error with a wrong password (confirmable)", %{
      confirmable_client_id: client_id
    } do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == "wrong password"

        {:error, :boom}
      end)

      context = :context
      authentication_params = %{email: username, password: "wrong password"}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "returns an error if not confirmed", %{
      confirmable_client_id: client_id
    } do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == valid_user_password()

        :ok
      end)

      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      assert {:authentication_failure, ^context,
              %SessionError{template: %Template{type: "new_confirmation_instructions"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Email confirmation is required to authenticate."
    end

    test "authenticates the user", %{client_id: client_id, backend: backend} do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == valid_user_password()

        :ok
      end)

      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      assert {:user_authenticated, ^context,
              %User{
                username: ^username,
                backend: ^backend,
                uid: ^uid,
                last_login_at: last_login_at
              },
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert last_login_at
      assert session_token
    end

    test "does not create multiple users accross multiple authentications", %{
      client_id: client_id,
      backend: backend
    } do
      uid = "ldap_uid"
      username = "ldap_username"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, 2, fn _handle, _backend, email ->
        {:ok, {"user_dn", %{"uid" => uid, "sn" => email}}}
      end)
      |> expect(:simple_bind, 2, fn _handle, dn, password ->
        assert dn == "user_dn"
        assert password == valid_user_password()

        :ok
      end)

      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      assert {:user_authenticated, ^context,
              %User{id: user_id, username: ^username, backend: ^backend, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token

      assert {:user_authenticated, ^context,
              %User{id: new_user_id, username: ^username, backend: ^backend, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token
      assert user_id == new_user_id
    end

    @tag :skip
    test "returns a valid session token"
  end

  describe "delete_session/4" do
    setup do
      client_identity_provider = BorutaIdentity.Factory.insert(:client_identity_provider)

      {:ok,
       backend: client_identity_provider.identity_provider.backend,
       client_id: client_identity_provider.client_id}
    end

    test "return a success when session does not exist", %{client_id: client_id} do
      context = :context
      session_token = "unexisting sessino"

      assert {:session_deleted, ^context} =
               Accounts.delete_session(
                 context,
                 client_id,
                 session_token,
                 DummySession
               )
    end

    test "deletes session", %{client_id: client_id, backend: backend} do
      context = :context
      %User{id: user_id, username: email} = user_fixture(%{backend: backend})
      authentication_params = %{email: email, password: valid_user_password()}

      assert {:user_authenticated, ^context, %User{id: ^user_id}, session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token
      assert Repo.get_by(UserToken, token: session_token)

      assert {:session_deleted, ^context} =
               Accounts.delete_session(
                 context,
                 client_id,
                 session_token,
                 DummySession
               )

      refute Repo.get_by(UserToken, token: session_token)
    end
  end

  @tag :skip
  test "initialize_password_instructions/3"

  @tag :skip
  test "send_reset_password_instructions/5"

  @tag :skip
  test "initialize_password_reset/3"

  describe "reset_password/4 with an internal backend" do
    setup do
      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              user_editable: true
            )
        )

      {:ok, client_id: client_identity_provider.client_id}
    end

    test "returns an error when password token is invalid", %{client_id: client_id} do
      user_token = insert(:reset_password_user_token)

      reset_password_params = %{
        reset_password_token: user_token.token
      }

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Given reset password token is invalid.",
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "returns an error when password params are invalid", %{client_id: client_id} do
      user = user_fixture()
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(user_token)

      reset_password_params = %{
        reset_password_token: token,
        password: "password",
        password_confirmation: "bad password confirmation"
      }

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Could not update user password.",
                changeset: %Ecto.Changeset{},
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "returns an error with an already used token", %{client_id: client_id} do
      user = user_fixture()
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(%{user_token | revoked_at: DateTime.utc_now()})
      password = "a good password"

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Given reset password token is invalid.",
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "resets user password", %{client_id: client_id} do
      %User{id: user_id} = user = user_fixture()
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(user_token)
      password = "a good password"

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      assert {:password_reseted, :context, %User{id: ^user_id}} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "invalidates reset password token", %{client_id: client_id} do
      %User{id: user_id} = user = user_fixture()
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, user_token} = Repo.insert(user_token)
      password = "a good password"

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      assert {:password_reseted, :context, %User{id: ^user_id}} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )

      assert %UserToken{revoked_at: revoked_at} = Repo.reload(user_token)
      assert revoked_at
    end
  end

  describe "reset_password/4 with an ldap backend" do
    setup do
      backend = insert(:ldap_backend)

      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              user_editable: true,
              backend: backend
            )
        )

      BorutaIdentity.LdapRepoMock
      |> stub(:open, fn host, _opts ->
        assert host == backend.ldap_host

        {:ok, :ldap_pid}
      end)
      |> stub(:close, fn _handle ->
        :ok
      end)

      {:ok, client_id: client_identity_provider.client_id, backend: backend}
    end

    test "returns an error when password token is invalid", %{client_id: client_id} do
      user_token = insert(:reset_password_user_token)

      reset_password_params = %{
        reset_password_token: user_token.token
      }

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Given reset password token is invalid.",
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "returns an error when password params are invalid (no ldap user)", %{
      client_id: client_id,
      backend: backend
    } do
      user = user_fixture(%{backend: backend})
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(user_token)

      reset_password_params = %{
        reset_password_token: token,
        password: "password",
        password_confirmation: "bad password confirmation"
      }

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Password and password confirmation do not match.",
                changeset: nil,
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "returns an error when password params are invalid (ldap password error)", %{
      client_id: client_id,
      backend: backend
    } do
      user = user_fixture(%{backend: backend})
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(user_token)

      reset_password_params = %{
        reset_password_token: token,
        password: "password that fails on ldap",
        password_confirmation: "password that fails on ldap"
      }

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify_password, fn _handle, _ldap_user, _password -> {:error, "ldap error"} end)

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "ldap error",
                changeset: nil,
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "returns an error with an already used token", %{client_id: client_id, backend: backend} do
      user = user_fixture(%{backend: backend})
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(%{user_token | revoked_at: DateTime.utc_now()})
      password = "a good password"

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      assert {:password_reset_failure, :context,
              %ResetPasswordError{
                message: "Given reset password token is invalid.",
                template: %Template{type: "edit_reset_password"}
              }} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "resets user password", %{client_id: client_id, backend: backend} do
      %User{id: user_id} = user = user_fixture(%{backend: backend})
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, _user_token} = Repo.insert(user_token)
      password = "a good password"

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify_password, fn _handle, _ldap_user, _password -> :ok end)

      assert {:password_reseted, :context, %User{id: ^user_id}} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )
    end

    test "invalidates reset password token", %{client_id: client_id, backend: backend} do
      %User{id: user_id} = user = user_fixture(%{backend: backend})
      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, user_token} = Repo.insert(user_token)
      password = "a good password"

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify_password, fn _handle, _ldap_user, _password -> :ok end)

      reset_password_params = %{
        reset_password_token: token,
        password: password,
        password_confirmation: password
      }

      assert {:password_reseted, :context, %User{id: ^user_id}} =
               Accounts.reset_password(
                 :context,
                 client_id,
                 reset_password_params,
                 DummyResetPasswords
               )

      assert %UserToken{revoked_at: revoked_at} = Repo.reload(user_token)
      assert revoked_at
    end
  end

  describe "initialize_edit_user/4" do
    setup do
      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              user_editable: true
            )
        )

      user = insert(:user)

      {:ok, client_id: client_identity_provider.client_id, user: user}
    end

    test "returns an error with nil client_id", %{user: user} do
      client_id = nil
      context = :context

      assert_raise IdentityProviderError, "Client identifier not provided.", fn ->
        Accounts.initialize_edit_user(context, client_id, user, DummySettings)
      end
    end

    test "returns an error with unknown client_id", %{user: user} do
      client_id = SecureRandom.uuid()
      context = :context

      assert_raise IdentityProviderError,
                   "identity provider not configured for given OAuth client. Please contact your administrator.",
                   fn ->
                     Accounts.initialize_edit_user(context, client_id, user, DummySettings)
                   end
    end

    test "returns an error if registration is not enabled for client identity provider", %{
      user: user
    } do
      %ClientIdentityProvider{client_id: client_id} = insert(:client_identity_provider)

      context = :context

      assert_raise IdentityProviderError,
                   "Feature is not enabled for client identity provider.",
                   fn ->
                     Accounts.initialize_edit_user(context, client_id, user, DummySettings)
                   end
    end

    test "returns a template", %{client_id: client_id, user: user} do
      context = :context

      assert {:edit_user_initialized, ^context, ^user, %Template{}} =
               Accounts.initialize_edit_user(context, client_id, user, DummySettings)
    end
  end

  describe "update_user/5 with internal backend" do
    setup do
      backend = insert(:backend)

      identity_provider =
        build(
          :identity_provider,
          user_editable: true,
          backend: backend
        )

      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider: identity_provider
        )

      user = user_fixture(%{backend: backend})

      {:ok, client_id: client_identity_provider.client_id, user: user, backend: backend}
    end

    test "returns an error with unexisting user", %{client_id: client_id} do
      user = %User{username: "unexisting"}
      confirmation_url_fun = fn -> "" end

      assert {:user_update_failure, :context,
              %SettingsError{message: "User not found.", template: %Template{type: "edit_user"}}} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "returns an error with a bad current password", %{client_id: client_id, user: user} do
      confirmation_url_fun = fn -> "" end

      assert {:user_update_failure, :context,
              %SettingsError{
                message: "Invalid user password.",
                template: %Template{type: "edit_user"}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: "bad password"},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "returns an error with bad update parameters", %{client_id: client_id, user: user} do
      confirmation_url_fun = fn -> "" end

      assert {:user_update_failure, :context,
              %SettingsError{
                message: "Could not update user with given params.",
                changeset: %Ecto.Changeset{},
                template: %Template{type: "edit_user"}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: valid_user_password(), email: ""},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user", %{client_id: client_id, user: user} do
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      assert {:user_updated, :context, %User{username: ^updated_email}} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: valid_user_password(), email: updated_email},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user with metadata", %{client_id: client_id, backend: backend} do
      user =
        user_fixture(%{
          backend: backend,
          metadata: %{"other" => %{"value" => "other", "status" => "valid", "display" => []}}
        })

      {:ok, _backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [
            %{"attribute_name" => "other", "user_editable" => false},
            %{"attribute_name" => "test", "user_editable" => true}
          ]
        })
        |> Repo.update()

      metadata = %{"test" => "test value"}
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      assert {:user_updated, :context,
              %User{
                username: ^updated_email,
                metadata: %{
                  "test" => %{"value" => "test value", "status" => "valid", "display" => []},
                  "other" => %{"value" => "other", "status" => "valid", "display" => []}
                }
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{
                   current_password: valid_user_password(),
                   email: updated_email,
                   metadata: metadata
                 },
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user with filtered metadata", %{
      client_id: client_id,
      user: user,
      backend: backend
    } do
      {:ok, _backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [
            %{"attribute_name" => "test", "user_editable" => true},
            %{"attribute_name" => "restricted_field", "user_editable" => false}
          ]
        })
        |> Repo.update()

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"restricted_field" => "restricted"}})
        |> Repo.update()

      metadata = %{"test" => "test value"}
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      assert {:user_updated, :context, %User{username: ^updated_email}} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{
                   current_password: valid_user_password(),
                   email: updated_email,
                   metadata:
                     metadata
                     |> Map.put("filtered", true)
                     |> Map.put("restricted_field", "update restricted")
                 },
                 confirmation_url_fun,
                 DummySettings
               )

      assert %User{
               metadata: %{
                 "restricted_field" => %{"status" => "valid", "value" => "restricted"},
                 "test" => %{"status" => "valid", "value" => "test value"}
               }
             } = Repo.reload(user)
    end

    @tag :skip
    test "unconfirms user"
  end

  @tag :skip
  describe "update_user/5 with ldap backend" do
    setup do
      backend = insert(:ldap_backend)

      identity_provider =
        build(
          :identity_provider,
          user_editable: true,
          backend: backend
        )

      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider: identity_provider
        )

      user = user_fixture(%{backend: backend})

      BorutaIdentity.LdapRepoMock
      |> stub(:open, fn host, _opts ->
        assert host == backend.ldap_host

        {:ok, :ldap_pid}
      end)
      |> stub(:close, fn _handle ->
        :ok
      end)

      {:ok, client_id: client_identity_provider.client_id, backend: backend, user: user}
    end

    test "returns an error with unexisting user", %{client_id: client_id} do
      user = %User{username: "unexisting"}
      confirmation_url_fun = fn -> "" end

      assert {:user_update_failure, :context,
              %SettingsError{message: "User not found.", template: %Template{type: "edit_user"}}} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "returns an error with a bad current password (no ldap user)", %{
      client_id: client_id,
      user: user
    } do
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:error, "ldap error"}
      end)

      assert {:user_update_failure, :context,
              %SettingsError{
                message: "ldap error",
                template: %Template{type: "edit_user"}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: "bad password"},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "returns an error with a bad current password (ldap password error)", %{
      client_id: client_id,
      backend: backend,
      user: user
    } do
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _dn, _password -> {:error, "ldap error"} end)

      assert {:user_update_failure, :context,
              %SettingsError{
                message: "Authentication failure.",
                template: %Template{type: "edit_user"}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: "bad password"},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "returns an error with bad update parameters", %{
      client_id: client_id,
      user: user,
      backend: backend
    } do
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _dn, _password -> :ok end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify, fn _handle, _backend, _user, "" -> {:error, "ldap error"} end)

      assert {:user_update_failure, :context,
              %SettingsError{
                message: "ldap error",
                template: %Template{type: "edit_user"}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: valid_user_password(), email: ""},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user", %{client_id: client_id, user: user, backend: backend} do
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _dn, _password -> :ok end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify, fn _handle, _backend, _user, ^updated_email -> :ok end)

      assert {:user_updated, :context, %User{username: ^updated_email}} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{current_password: valid_user_password(), email: updated_email},
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user with metadata", %{client_id: client_id, user: user, backend: backend} do
      {:ok, _backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [%{"attribute_name" => "test", "user_editable" => true}]
        })
        |> Repo.update()

      metadata = %{"test" => "test value"}
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _dn, _password -> :ok end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify, fn _handle, _backend, _user, ^updated_email -> :ok end)

      assert {:user_updated, :context,
              %User{
                username: ^updated_email,
                metadata: %{"test" => %{"value" => "test value", "status" => "valid"}}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{
                   current_password: valid_user_password(),
                   email: updated_email,
                   metadata: metadata
                 },
                 confirmation_url_fun,
                 DummySettings
               )
    end

    test "updates user with filtered metadata", %{
      client_id: client_id,
      user: user,
      backend: backend
    } do
      Ecto.Changeset.change(backend, %{
        metadata_fields: [
          %{"attribute_name" => "test", "user_editable" => true},
          %{"attribute_name" => "restricted_field", "user_editable" => false}
        ]
      })
      |> Repo.update()

      metadata = %{"test" => "test value"}
      updated_email = "updated@email.test"
      confirmation_url_fun = fn -> "" end

      BorutaIdentity.LdapRepoMock
      |> expect(:search, fn _handle, _backend, _email ->
        {:ok, {"dn", %{"uid" => "uid", backend.ldap_user_rdn_attribute => "username"}}}
      end)
      |> expect(:simple_bind, fn _handle, _dn, _password -> :ok end)
      |> expect(:simple_bind, fn _handle, _master_dn, _master_password -> :ok end)
      |> expect(:modify, fn _handle, _backend, _user, ^updated_email -> :ok end)

      assert {:user_updated, :context,
              %User{
                username: ^updated_email,
                metadata: %{"test" => %{"value" => "test value", "status" => "valid"}}
              }} =
               Accounts.update_user(
                 :context,
                 client_id,
                 user,
                 %{
                   current_password: valid_user_password(),
                   email: updated_email,
                   metadata:
                     metadata
                     |> Map.put("filtered", true)
                     |> Map.put("restricted_field", "restricted")
                 },
                 confirmation_url_fun,
                 DummySettings
               )
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email(Backend.default!(), "unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.backend, user.username)
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = BorutaIdentityWeb.ConnCase.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "send_confirmation_instructions/5" do
    test "returns a success" do
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider, confirmable: true)

      %ClientIdentityProvider{client_id: client_id} =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider: identity_provider
        )

      context = :context

      confirmation_params = %{
        email: "unknown@test.test"
      }

      confirmation_url_fun = & &1

      assert Accounts.send_confirmation_instructions(
               context,
               client_id,
               confirmation_params,
               confirmation_url_fun,
               DummyConfirmation
             ) == {
               :confirmation_instructions_delivered,
               context
             }
    end

    @tag :skip
    test "delivers confirmation instructions when user is known"
  end

  @tag :skip
  test "confirm_user/4"

  @tag :skip
  test "initialize_consent/4"

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "get_user_scopes/1" do
    test "returns an empty list" do
      user = user_fixture()

      assert Accounts.get_user_scopes(user.id) == []
    end

    test "returns authorized scopes" do
      user = user_fixture()
      user_scope = user_scopes_fixture(user)

      scope_id = user_scope.scope_id

      assert [%Boruta.Oauth.Scope{id: ^scope_id, name: "name"}] =
               Accounts.get_user_scopes(user.id)
    end
  end

  @tag :skip
  test "consent/5"
end
