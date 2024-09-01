defmodule BorutaIdentity.TotpTest do
  defmodule DummyTotpRegistrationApplication do
    @behaviour BorutaIdentity.TotpRegistrationApplication

    @impl BorutaIdentity.TotpRegistrationApplication
    def totp_registration_initialized(context, totp_secret, template) do
      {:totp_registration_initialized, context, totp_secret, template}
    end

    @impl BorutaIdentity.TotpRegistrationApplication
    def totp_registration_error(context, error) do
      {:totp_registration_error, context, error}
    end

    @impl BorutaIdentity.TotpRegistrationApplication
    def totp_registration_success(context, user) do
      {:totp_registration_success, context, user}
    end
  end

  defmodule DummyTotpAuthenticationApplication do
    @behaviour BorutaIdentity.TotpAuthenticationApplication

    @impl BorutaIdentity.TotpAuthenticationApplication
    def totp_initialized(context, template) do
      {:totp_initialized, context, template}
    end

    @impl BorutaIdentity.TotpAuthenticationApplication
    def totp_not_required(context) do
      {:totp_not_required, context}
    end

    @impl BorutaIdentity.TotpAuthenticationApplication
    def totp_registration_missing(context) do
      {:totp_registration_missing, context}
    end

    @impl BorutaIdentity.TotpAuthenticationApplication
    def totp_authenticated(context, current_user) do
      {:totp_authenticated, context, current_user}
    end

    @impl BorutaIdentity.TotpAuthenticationApplication
    def totp_authentication_failure(context, error) do
      {:totp_authentication_failure, context, error}
    end
  end

  defmodule HotpTest do
    use ExUnit.Case

    alias BorutaIdentity.Totp.Hotp

    test "returns an htop given empty params" do
      assert Hotp.generate_hotp("", 0) == "328482"
    end

    test "returns an hotp with RFC examples" do
      assert Hotp.generate_hotp("12345678901234567890", 0) == "755224"
      assert Hotp.generate_hotp("12345678901234567890", 1) == "287082"
      assert Hotp.generate_hotp("12345678901234567890", 2) == "359152"
      assert Hotp.generate_hotp("12345678901234567890", 3) == "969429"
      assert Hotp.generate_hotp("12345678901234567890", 4) == "338314"
      assert Hotp.generate_hotp("12345678901234567890", 5) == "254676"
      assert Hotp.generate_hotp("12345678901234567890", 6) == "287922"
      assert Hotp.generate_hotp("12345678901234567890", 7) == "162583"
      assert Hotp.generate_hotp("12345678901234567890", 8) == "399871"
      assert Hotp.generate_hotp("12345678901234567890", 9) == "520489"
    end
  end

  defmodule AdminTest do
    use ExUnit.Case

    alias BorutaIdentity.Totp.Admin

    describe "generate_totp/1" do
      test "returns an error with a non base32 encoded secret" do
        assert :error = Admin.generate_totp("not base64 encoded secret")
      end

      test "returns a totp" do
        secret = Base.encode32("secret", padding: false)

        # TODO test only the presence until we have a timestamp provider
        assert Admin.generate_totp(secret) |> String.length() == 6
      end
    end

    describe "check_totp/2" do
      test "returns an error when totp invalid" do
        secret = Base.encode32("secret", padding: false)

        assert {:error, "Given TOTP is invalid."} = Admin.check_totp("invalid", secret)
      end

      test "returns an error when secret is bad encoded invalid" do
        secret = "bad encoding"

        assert {:error, "Given TOTP is invalid."} = Admin.check_totp("whatever", secret)
      end
    end

    describe "generate_secret/0" do
      test "return a random secret" do
        # secret is hashed from an uuid
        assert {:ok, _} =
                 Admin.generate_secret()
                 |> Base.decode32!(padding: false)
                 |> Ecto.UUID.cast()
      end
    end
  end

  use BorutaIdentity.DataCase

  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Totp

  describe "initialize_totp_registration/3" do
    setup do
      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              totpable: true
            )
        )

      {:ok, client_id: client_identity_provider.client_id}
    end

    test "raises an error", %{client_id: client_id} do
      assert_raise BorutaIdentity.TotpError, fn ->
        Totp.initialize_totp_registration(
          :context,
          client_id,
          false,
          %User{totp_registered_at: DateTime.utc_now()},
          DummyTotpRegistrationApplication
        )
      end
    end

    test "returns a secret and the registration template when not registered", %{client_id: client_id} do
      assert {:totp_registration_initialized, :context, totp_secret, template} =
               Totp.initialize_totp_registration(
                 :context,
                 client_id,
                 false,
                 %User{},
                 DummyTotpRegistrationApplication
               )

      # secret is hashed from an uuid
      assert {:ok, _} =
               totp_secret
               |> Base.decode32!(padding: false)
               |> Ecto.UUID.cast()

      assert Regex.match?(
               ~r/Add TOTP authentication from an authenticator/,
               template.content
             )
    end

    test "returns a secret and the registration template when totp authenticated", %{client_id: client_id} do
      assert {:totp_registration_initialized, :context, totp_secret, template} =
               Totp.initialize_totp_registration(
                 :context,
                 client_id,
                 true,
                 %User{},
                 DummyTotpRegistrationApplication
               )

      # secret is hashed from an uuid
      assert {:ok, _} =
               totp_secret
               |> Base.decode32!(padding: false)
               |> Ecto.UUID.cast()

      assert Regex.match?(
               ~r/Add TOTP authentication from an authenticator/,
               template.content
             )
    end
  end

  describe "register_totp/4" do
    setup do
      client_identity_provider =
        BorutaIdentity.Factory.insert(:client_identity_provider,
          identity_provider:
            build(
              :identity_provider,
              totpable: true
            )
        )

      user = BorutaIdentity.Factory.insert(:user)

      {:ok, client_id: client_identity_provider.client_id, user: user}
    end

    test "returns an error with registration template if bad secret format", %{
      client_id: client_id,
      user: current_user
    } do
      totp_params = %{
        totp_code: "totp_code",
        totp_secret: "bad_totp_secret"
      }

      assert {:totp_registration_error, :context, error} =
               Totp.register_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpRegistrationApplication
               )

      assert error.message == "Given TOTP is invalid."

      assert Regex.match?(
               ~r/Add TOTP authentication from an authenticator/,
               error.template.content
             )
    end

    test "returns an error with registration template if totp is invalid (bad code)", %{
      client_id: client_id,
      user: current_user
    } do
      totp_params = %{
        totp_code: "totp_code",
        totp_secret: Totp.Admin.generate_secret()
      }

      assert {:totp_registration_error, :context, error} =
               Totp.register_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpRegistrationApplication
               )

      assert error.message == "Given TOTP is invalid."

      assert Regex.match?(
               ~r/Add TOTP authentication from an authenticator/,
               error.template.content
             )
    end

    # NOTE can be a flaky test, mind about time provider
    test "successes when TOTP is valid", %{
      client_id: client_id,
      user: current_user
    } do
      secret = Totp.Admin.generate_secret()

      totp_params = %{
        totp_code: Totp.Admin.generate_totp(secret),
        totp_secret: secret
      }

      assert {:totp_registration_success, :context, user} =
               Totp.register_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpRegistrationApplication
               )

      assert user.totp_registered_at
      assert user.totp_secret == secret
    end
  end

  describe "initialize_totp/4" do
    setup do
      client_id =
        for totpable <- [true, false], enforce_totp <- [true, false] do
          current_client_id =
            BorutaIdentity.Factory.insert(:client_identity_provider,
              identity_provider:
                build(
                  :identity_provider,
                  totpable: totpable,
                  enforce_totp: enforce_totp
                )
            ).client_id

          label =
            case {totpable, enforce_totp} do
              {true, true} -> :totpable_enforce_totp
              {true, false} -> :totpable
              {false, true} -> :enforce_totp
              {false, false} -> :basic
            end

          {label, current_client_id}
        end
        |> Enum.into(%{})

      user = BorutaIdentity.Factory.insert(:user)

      registered_user =
        BorutaIdentity.Factory.insert(:user, totp_registered_at: DateTime.utc_now())

      {:ok, client_id: client_id, user: user, registered_user: registered_user}
    end

    test "returns not required if identity provider is basic", %{
      client_id: %{basic: client_id},
      user: current_user
    } do
      assert {:totp_not_required, :context} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns registration missing if identity provider enforces totp", %{
      client_id: %{enforce_totp: client_id},
      user: current_user
    } do
      assert {:totp_registration_missing, :context} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns authentication template if identity provider enforces totp and user registred",
         %{
           client_id: %{enforce_totp: client_id},
           registered_user: current_user
         } do
      assert {:totp_initialized, :context, template} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )

      assert Regex.match?(
               ~r/Provide the TOTP code from your authenticator/,
               template.content
             )
    end

    test "returns not required if identity provider is totpable", %{
      client_id: %{totpable: client_id},
      user: current_user
    } do
      assert {:totp_not_required, :context} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns authentication template if identity provider is totpable and user registered",
         %{
           client_id: %{totpable: client_id},
           registered_user: current_user
         } do
      assert {:totp_initialized, :context, template} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )

      assert Regex.match?(
               ~r/Provide the TOTP code from your authenticator/,
               template.content
             )
    end

    test "returns registration missing if identity provider totpable and enforces totp", %{
      client_id: %{totpable_enforce_totp: client_id},
      user: current_user
    } do
      assert {:totp_registration_missing, :context} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns authentication template if identity provider is totpable, enforces totp and user registered",
         %{
           client_id: %{totpable_enforce_totp: client_id},
           registered_user: current_user
         } do
      assert {:totp_initialized, :context, template} =
               Totp.initialize_totp(
                 :context,
                 client_id,
                 current_user,
                 DummyTotpAuthenticationApplication
               )

      assert Regex.match?(
               ~r/Provide the TOTP code from your authenticator/,
               template.content
             )
    end
  end

  describe "authenticate_totp/5" do
    setup do
      client_id =
        for totpable <- [true, false], enforce_totp <- [true, false] do
          current_client_id =
            BorutaIdentity.Factory.insert(:client_identity_provider,
              identity_provider:
                build(
                  :identity_provider,
                  totpable: totpable,
                  enforce_totp: enforce_totp
                )
            ).client_id

          label =
            case {totpable, enforce_totp} do
              {true, true} -> :totpable_enforce_totp
              {true, false} -> :totpable
              {false, true} -> :enforce_totp
              {false, false} -> :basic
            end

          {label, current_client_id}
        end
        |> Enum.into(%{})

      user = BorutaIdentity.Factory.insert(:user)

      registered_user =
        BorutaIdentity.Factory.insert(:user,
          totp_registered_at: DateTime.utc_now(),
          totp_secret: Totp.Admin.generate_secret()
        )

      {:ok, client_id: client_id, user: user, registered_user: registered_user}
    end

    test "raises an error if identity provider is basic", %{
      client_id: %{basic: client_id},
      user: current_user
    } do
      totp_params = %{}

      assert_raise IdentityProviderError, fn ->
        Totp.authenticate_totp(
          :context,
          client_id,
          current_user,
          totp_params,
          DummyTotpAuthenticationApplication
        )
      end
    end

    test "raises an error if identity provider enforces totp", %{
      client_id: %{enforce_totp: client_id},
      user: current_user
    } do
      totp_params = %{}

      assert_raise IdentityProviderError, fn ->
        Totp.authenticate_totp(
          :context,
          client_id,
          current_user,
          totp_params,
          DummyTotpAuthenticationApplication
        )
      end
    end

    test "returns not required if identity provider is totpable", %{
      client_id: %{totpable: client_id},
      user: current_user
    } do
      totp_params = %{}

      assert {:totp_not_required, :context} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns authentication failure if identity provider is totpable, and user registered",
         %{
           client_id: %{totpable: client_id},
           registered_user: current_user
         } do
      totp_params = %{
        totp_code: "bad code"
      }

      assert {:totp_authentication_failure, :context, error} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )

      assert error.message == "Given TOTP is invalid."

      assert Regex.match?(
               ~r/Provide the TOTP code from your authenticator/,
               error.template.content
             )
    end

    test "authenticates if identity provider is totpable, user registered and valid totp",
         %{
           client_id: %{totpable: client_id},
           registered_user: current_user
         } do
      totp_params = %{
        totp_code: Totp.Admin.generate_totp(current_user.totp_secret)
      }

      assert {:totp_authenticated, :context, %User{}} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns registration missing if identity provider totpable and enforces totp", %{
      client_id: %{totpable_enforce_totp: client_id},
      user: current_user
    } do
      totp_params = %{}

      assert {:totp_registration_missing, :context} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )
    end

    test "returns an error if identity provider is totpable, enforces totp and user registered",
         %{
           client_id: %{totpable_enforce_totp: client_id},
           registered_user: current_user
         } do
      totp_params = %{}

      assert {:totp_authentication_failure, :context, error} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )

      assert error.message == "Given TOTP is invalid."

      assert Regex.match?(
               ~r/Provide the TOTP code from your authenticator/,
               error.template.content
             )
    end

    test "authenticates if identity provider is totpable, enforces totp, user registered and totp valid",
         %{
           client_id: %{totpable_enforce_totp: client_id},
           registered_user: current_user
         } do
      totp_params = %{
        totp_code: Totp.Admin.generate_totp(current_user.totp_secret)
      }

      assert {:totp_authenticated, :context, %User{}} =
               Totp.authenticate_totp(
                 :context,
                 client_id,
                 current_user,
                 totp_params,
                 DummyTotpAuthenticationApplication
               )
    end
  end
end
