defmodule BorutaIdentity.AccountsTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.{User, UserAuthorizedScope, UserToken}
  alias BorutaIdentity.RelyingParties.ClientRelyingParty
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.RelyingParties.Template
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

    @impl Accounts.RegistrationApplication
    def invalid_relying_party(context, error) do
      {:invalid_relying_party, context, error}
    end
  end

  defmodule DummySession do
    @behaviour Accounts.SessionApplication

    @impl Accounts.SessionApplication
    def session_initialized(context, relying_party, template) do
      {:session_initialized, context, relying_party, template}
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

    @impl Accounts.SessionApplication
    def invalid_relying_party(context, error) do
      {:invalid_relying_party, context, error}
    end
  end

  describe "Utils.client_relying_party/1" do
    test "returns an error when client_id is nil" do
      client_id = nil

      assert Accounts.Utils.client_relying_party(client_id) ==
               {:error, "Client identifier not provided."}
    end

    test "returns an error when client_id is unknown" do
      client_id = SecureRandom.uuid()

      assert Accounts.Utils.client_relying_party(client_id) ==
               {:error,
                "Relying Party not configured for given OAuth client. " <>
                  "Please contact your administrator."}
    end

    test "returns client relying_party" do
      relying_party = BorutaIdentity.Factory.insert(:relying_party, type: "internal")

      %ClientRelyingParty{client_id: client_id} =
        BorutaIdentity.Factory.insert(:client_relying_party, relying_party: relying_party)

      assert Accounts.Utils.client_relying_party(client_id) == {:ok, relying_party}
    end
  end

  describe "initialize_registration/3" do
    setup do
      client_relying_party =
        BorutaIdentity.Factory.insert(:client_relying_party,
          relying_party: build(
            :relying_party,
            registrable: true
          )
        )

      {:ok, client_id: client_relying_party.client_id}
    end

    test "returns an error with nil client_id" do
      client_id = nil
      context = :context

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.initialize_registration(context, client_id, DummyRegistration)

      assert error.message == "Client identifier not provided."
    end

    test "returns an error with unknown client_id" do
      client_id = SecureRandom.uuid()
      context = :context

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.initialize_registration(context, client_id, DummyRegistration)

      assert error.message ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."
    end

    test "returns an error if registration is not enabled for client relying party" do
      %ClientRelyingParty{client_id: client_id} = insert(:client_relying_party)

      context = :context

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.initialize_registration(context, client_id, DummyRegistration)

      assert error.message ==
               "Feature is not enabled for client relying party."
    end

    test "returns a template", %{client_id: client_id} do
      context = :context

      assert {:registration_initialized, ^context, %Template{}} =
               Accounts.initialize_registration(context, client_id, DummyRegistration)
    end
  end

  describe "register/3" do
    setup do
      client_relying_party =
        BorutaIdentity.Factory.insert(:client_relying_party,
          relying_party: build(
            :relying_party,
            registrable: true
          )
        )

      {:ok, client_id: client_relying_party.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      user_params = %{}
      confirmation_callback_fun = & &1

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert error.message == "Client identifier not provided."
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      user_params = %{}
      confirmation_callback_fun = & &1

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert error.message ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."
    end

    test "returns an error if registrations is disabled for client relying party" do
      %ClientRelyingParty{client_id: client_id} = insert(:client_relying_party)
      context = :context
      user_params = %{}
      confirmation_callback_fun = & &1

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.register(
                 context,
                 client_id,
                 user_params,
                 confirmation_callback_fun,
                 DummyRegistration
               )

      assert error.message ==
               "Feature is not enabled for client relying party."
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
      %{email: email} = user_fixture()
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
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    @tag :skip
    test "delivers a confirmation mail"
  end

  describe "initialize_session/3" do
    setup do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      {:ok, client_id: client_relying_party.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.initialize_session(
                 context,
                 client_id,
                 DummySession
               )

      assert error.message == "Client identifier not provided."
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.initialize_session(
                 context,
                 client_id,
                 DummySession
               )

      assert error.message ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."
    end

    test "returns relying party and a template", %{client_id: client_id} do
      context = :context

      assert {:session_initialized, ^context, %RelyingParty{}, %Template{type: "new_session"}} =
               Accounts.initialize_session(
                 context,
                 client_id,
                 DummySession
               )
    end
  end

  describe "create_session/4" do
    setup do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      {:ok, client_id: client_relying_party.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      authentication_params = %{}

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message == "Client identifier not provided."
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      authentication_params = %{}

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."
    end

    test "returns an error with empty authentication params", %{client_id: client_id} do
      context = :context
      authentication_params = %{}

      assert {:authentication_failure, ^context, %SessionError{template: %Template{type: "new_session"}} = error} =
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

      assert {:authentication_failure, ^context, %SessionError{template: %Template{type: "new_session"}} = error} =
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
      %User{email: email} = user_fixture()
      context = :context
      authentication_params = %{email: email}

      assert {:authentication_failure, ^context, %SessionError{template: %Template{type: "new_session"}} = error} =
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
      %User{email: email} = user_fixture()
      context = :context
      authentication_params = %{email: email, password: "wrong password"}

      assert {:authentication_failure, ^context, %SessionError{template: %Template{type: "new_session"}} = error} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert error.message ==
               "Invalid email or password."
    end

    test "authenticates the user", %{client_id: client_id} do
      %User{email: email} = user = user_fixture()
      context = :context
      authentication_params = %{email: email, password: valid_user_password()}

      assert {:user_authenticated, ^context, ^user, session_token} =
               Accounts.create_session(
                 context,
                 client_id,
                 authentication_params,
                 DummySession
               )

      assert session_token
    end

    @tag :skip
    test "returns a valid session token"
  end

  describe "delete_session/4" do
    setup do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      {:ok, client_id: client_relying_party.client_id}
    end

    test "returns an error with nil client_id" do
      context = :context
      client_id = nil
      session_token = ""

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.delete_session(
                 context,
                 client_id,
                 session_token,
                 DummySession
               )

      assert error.message == "Client identifier not provided."
    end

    test "returns an error with unknown client_id" do
      context = :context
      client_id = SecureRandom.uuid()
      session_token = ""

      assert {:invalid_relying_party, ^context, %RelyingPartyError{} = error} =
               Accounts.delete_session(
                 context,
                 client_id,
                 session_token,
                 DummySession
               )

      assert error.message ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."
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
      %User{email: email} = user = user_fixture()
      authentication_params = %{email: email, password: valid_user_password()}

      assert {:user_authenticated, ^context, ^user, session_token} =
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

  describe "list_users/0" do
    test "returns an empty list" do
      assert Accounts.list_users() == []
    end

    test "returns users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user(user.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert user = Accounts.get_user_by_email(user.email)

      assert {:ok, _user} =
               Accounts.Internal.check_user_against(user, %{password: "new valid password"})
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "delete_user/1" do
    test "returns an error" do
      assert Accounts.delete_user(Ecto.UUID.generate()) == {:error, "User not found."}
    end

    test "returns deleted user" do
      %User{id: user_id} = user_fixture()
      assert {:ok, %User{id: ^user_id}} = Accounts.delete_user(user_id)
      assert Repo.get(User, user_id) == nil
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
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

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      confirmation_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Accounts.deliver_user_confirmation_instructions(user, confirmation_url_fun)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/2" do
    setup do
      user = user_fixture()

      confirmation_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Accounts.deliver_user_confirmation_instructions(user, confirmation_url_fun)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "update_user_authorized_scopes/2" do
    test "returns an error on duplicates" do
      user = user_fixture()

      {:error, %Ecto.Changeset{} = changeset} =
        Accounts.update_user_authorized_scopes(user, [%{"name" => "test"}, %{"name" => "test"}])

      assert changeset
    end

    test "stores user scopes" do
      user = user_fixture()

      {:ok,
       %User{
         authorized_scopes:
           [
             %UserAuthorizedScope{
               name: "test"
             }
           ] = authorized_scopes
       }} = Accounts.update_user_authorized_scopes(user, [%{"name" => "test"}])

      assert Repo.all(UserAuthorizedScope) == authorized_scopes
    end
  end

  describe "get_user_scopes/1" do
    test "returns an empty list" do
      user = user_fixture()

      assert Accounts.get_user_scopes(user.id) == []
    end

    test "returns authorized scopes" do
      user = user_fixture()
      scope = user_scopes_fixture(user)

      assert Accounts.get_user_scopes(user.id) == [scope]
    end
  end

  describe "consent/2" do
    setup do
      user = user_fixture()

      {:ok, user: user}
    end

    test "returns an error with invalid params", %{user: user} do
      scopes = []
      client_id = nil

      assert {:error, %Ecto.Changeset{}} =
               Accounts.consent(user, %{"client_id" => client_id, "scopes" => scopes})
    end

    test "adds user consent for a given client_id", %{user: user} do
      scopes = ["scope:a", "scope:b"]
      client_id = "client_id"

      {:ok, %User{consents: [consent]}} =
        Accounts.consent(user, %{"client_id" => client_id, "scopes" => scopes})

      assert consent.client_id == client_id
      assert consent.scopes == scopes

      %User{consents: [consent]} = Repo.one(User) |> Repo.preload(:consents)

      assert consent.client_id == client_id
      assert consent.scopes == scopes
    end
  end

  describe "consented?/2" do
    setup do
      user = user_fixture()
      client_id = SecureRandom.uuid()
      redirect_uri = "http://test.host"
      consent = insert(:consent, user: user, scopes: ["consented", "scope"])

      oauth_request = %Plug.Conn{
        query_params: %{
          "scope" => "",
          "response_type" => "token",
          "client_id" => client_id,
          "redirect_uri" => redirect_uri
        }
      }

      oauth_request_with_scope = %Plug.Conn{
        query_params: %{
          "scope" => "scope:a scope:b",
          "response_type" => "token",
          "client_id" => client_id,
          "redirect_uri" => redirect_uri
        }
      }

      oauth_request_with_consented_scope = %Plug.Conn{
        query_params: %{
          "scope" => "consented scope",
          "response_type" => "token",
          "client_id" => consent.client_id,
          "redirect_uri" => redirect_uri
        }
      }

      {:ok,
       user: user,
       oauth_request: oauth_request,
       oauth_request_with_scope: oauth_request_with_scope,
       oauth_request_with_consented_scope: oauth_request_with_consented_scope}
    end

    test "returns false with not an oauth request", %{user: user} do
      assert Accounts.consented?(user, %Plug.Conn{}) == false
    end

    test "returns true with empty scope", %{user: user, oauth_request: oauth_request} do
      assert Accounts.consented?(user, oauth_request) == true
    end

    test "returns false when scopes are not consented", %{
      user: user,
      oauth_request_with_scope: oauth_request
    } do
      assert Accounts.consented?(user, oauth_request) == false
    end

    test "returns true when scopes are consented", %{
      user: user,
      oauth_request_with_consented_scope: oauth_request
    } do
      assert Accounts.consented?(user, oauth_request) == true
    end
  end

  describe "consented_scopes/2" do
    setup do
      user = user_fixture()
      client_id = SecureRandom.uuid()
      consent = insert(:consent, user: user, scopes: ["consented:scope"])

      redirect_uri = "http://test.host"

      oauth_request = %Plug.Conn{
        query_params: %{
          "scope" => "",
          "response_type" => "token",
          "client_id" => client_id,
          "redirect_uri" => redirect_uri
        }
      }

      oauth_request_with_consented_scopes = %Plug.Conn{
        query_params: %{
          "scope" => "scope:a scope:b",
          "response_type" => "token",
          "client_id" => consent.client_id,
          "redirect_uri" => redirect_uri
        }
      }

      {:ok,
       user: user,
       consent: consent,
       oauth_request: oauth_request,
       oauth_request_with_consented_scopes: oauth_request_with_consented_scopes}
    end

    test "returns an empty array", %{user: user} do
      assert Accounts.consented_scopes(user, %Plug.Conn{}) == []
    end

    test "returns an empty array with a valid oauth request", %{
      user: user,
      oauth_request: oauth_request
    } do
      assert Accounts.consented_scopes(user, oauth_request) == []
    end

    test "returns existing consented scopes", %{
      user: user,
      oauth_request_with_consented_scopes: oauth_request
    } do
      assert Accounts.consented_scopes(user, oauth_request) == ["consented:scope"]
    end
  end
end
