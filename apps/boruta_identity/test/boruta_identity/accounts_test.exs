defmodule BorutaIdentity.AccountsTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.{User, UserToken}
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

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

  describe "create_session/4" do
    setup do
      confirmable_client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: insert(:identity_provider, confirmable: true)
        )

      client_identity_provider = BorutaIdentity.Factory.insert(:client_identity_provider)

      {:ok,
       client_id: client_identity_provider.client_id,
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

    test "returns an error with empty authentication params", %{client_id: client_id} do
      context = :context
      authentication_params = %{}

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

    test "returns an error if not confirmed", %{confirmable_client_id: client_id} do
      %Internal.User{email: email} = insert(:internal_user)
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

    test "authenticates the user", %{client_id: client_id} do
      %Internal.User{id: uid, email: username} = insert(:internal_user)
      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      provider = to_string(Internal)

      assert {:user_authenticated, ^context,
              %User{username: ^username, provider: ^provider, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token
    end

    test "does not create multiple users accross multiple authentications", %{
      client_id: client_id
    } do
      %Internal.User{id: uid, email: username} = insert(:internal_user)
      context = :context
      authentication_params = %{email: username, password: valid_user_password()}

      provider = to_string(Internal)

      assert {:user_authenticated, ^context,
              %User{id: user_id, username: ^username, provider: ^provider, uid: ^uid},
              session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token

      assert {:user_authenticated, ^context,
              %User{id: new_user_id, username: ^username, provider: ^provider, uid: ^uid},
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

      {:ok, client_id: client_identity_provider.client_id}
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

    test "deletes session", %{client_id: client_id} do
      context = :context
      %User{id: user_id, username: email} = user_fixture()
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

  @tag :skip
  test "reset_password/4"

  @tag :skip
  test "initialize_edit_user/4"

  @tag :skip
  test "edit_user/5"

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.username)
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

  describe "send_confirmation_instructions/4" do
    test "returns a success" do
      context = :context

      confirmation_params = %{
        email: "unknown@test.test"
      }

      confirmation_url_fun = & &1

      assert Accounts.send_confirmation_instructions(
               context,
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
