defmodule BorutaIdentity.Accounts.Utils do
  @moduledoc false

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  @spec client_implementation(client_id :: String.t() | nil) ::
          {:ok, implementation :: atom()} | {:error, reason :: String.t()}
  def client_implementation(nil), do: {:error, "Client identifier not provided."}

  def client_implementation(client_id) do
    case RelyingParties.get_relying_party_by_client_id(client_id) do
      %RelyingParty{} = relying_party ->
        {:ok, RelyingParty.implementation(relying_party)}

      nil ->
        {:error,
         "Relying Party not configured for given OAuth client. Please contact your administrator."}
    end
  end

  @doc """
  Adds `client_impl` variable in function body context. The function definition must have
  `context`, `client_id` and `module' as parameters.
  """
  # TODO find a better way to delegate to the given client impl
  defmacro defwithclientimpl(fun, do: block) do
    fun = Macro.escape(fun, unquote: true)
    block = Macro.escape(block, unquote: true)

    quote bind_quoted: [fun: fun, block: block] do
      {name, params} = Macro.decompose_call(fun)
      context_param = Enum.find(params, fn {var, _, _} -> var == :context end) ||
        raise "`context` must be part of function parameters"

      client_id_param = Enum.find(params, fn {var, _, _} -> var == :client_id end) ||
        raise "`client_id` must be part of function parameters"

      module_param = Enum.find(params, fn {var, _, _} -> var == :module end) ||
        raise "`module` must be part of function parameters"

      def unquote({name, [line: __ENV__.line], params}) do
        case BorutaIdentity.Accounts.Utils.client_implementation(unquote(client_id_param)) do
          {:ok, var!(client_impl)} ->
            unquote(block)

          {:error, reason} ->
            unquote(module_param).invalid_relying_party(
              unquote(context_param),
              %BorutaIdentity.Accounts.RelyingPartyError{
                message: reason
              }
            )
        end
      end
    end
  end
end

defmodule BorutaIdentity.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias BorutaIdentity.Accounts.Confirmations
  alias BorutaIdentity.Accounts.Consents
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.Registrations
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.Users

  import BorutaIdentity.Accounts.Utils, only: [defwithclientimpl: 2]

  defmodule RelyingPartyError do
    @enforce_keys [:message]
    defexception [:message]

    @type t :: %__MODULE__{
            message: String.t()
          }

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message}
    end

    def message(exception) do
      exception.message
    end
  end

  ## Registrations

  defmodule RegistrationError do
    @enforce_keys [:message]
    defexception [:message, :changeset]

    @type t :: %__MODULE__{
            message: String.t(),
            changeset: Ecto.Changeset.t() | nil
          }

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message}
    end

    def message(exception) do
      exception.message
    end
  end

  defmodule RegistrationApplication do
    @moduledoc """
    TODO RegistrationApplication documentation
    """

    @callback user_initialized(context :: any(), changeset :: Ecto.Changeset.t()) :: any()

    @callback user_registered(context :: any(), user :: User.t(), session_token :: String.t()) ::
                any()

    @callback registration_failure(
                context :: any(),
                error :: RegistrationError.t()
              ) :: any()

    @callback invalid_relying_party(
                context :: any(),
                error :: RelyingPartyError.t()
              ) :: any()
  end

  @spec initialize_registration(context :: any(), client_id :: String.t(), module :: atom()) ::
          callback_result :: any()
  defwithclientimpl initialize_registration(context, client_id, module) do
    changeset = apply(client_impl, :registration_changeset, [%User{}])

    module.user_initialized(context, changeset)
  end

  @callback registration_changeset(user :: User.t()) :: changeset :: Ecto.Changeset.t()

  @spec register(
          context :: any(),
          client_id :: String.t(),
          registration_params :: map(),
          confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t()),
          module :: atom()
        ) :: calback_result :: any()
  defwithclientimpl register(
                      context,
                      client_id,
                      registration_params,
                      confirmation_url_fun,
                      module
                    ) do
    with {:ok, user} <- apply(client_impl, :register, [registration_params, confirmation_url_fun]),
         {:ok, session_token} <- apply(client_impl, :create_session, [user]) do
      module.user_registered(context, user, session_token)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        module.registration_failure(context, %RegistrationError{
          changeset: changeset,
          message: "Could not create user with given params."
        })

      {:error, reason} ->
        module.registration_failure(context, %RegistrationError{message: reason})
    end
  end

  @callback register(
              user_params :: map(),
              confirmation_url_fun :: (token :: String.t() -> confirmation_url :: String.t())
            ) ::
              {:ok, user :: User.t()}
              | {:error, reason :: String.t()}
              | {:error, changeset :: Ecto.Changeset.t()}

  ## Sessions

  defmodule SessionError do
    @enforce_keys [:message]
    defexception [:message, :changeset]

    @type t :: %__MODULE__{
            message: String.t(),
            changeset: Ecto.Changeset.t() | nil
          }

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message}
    end

    def message(exception) do
      exception.message
    end
  end

  defmodule SessionApplication do
    @moduledoc """
    TODO SessionApplication documentation
    """

    @callback user_authenticated(context :: any(), user :: User.t(), session_token :: String.t()) ::
                any()

    @callback authentication_failure(context :: any(), error :: SessionError.t()) ::
                any()

    @callback session_deleted(context :: any()) :: any()

    @callback invalid_relying_party(
                context :: any(),
                error :: RelyingPartyError.t()
              ) :: any()
  end

  @type authentication_params :: %{
          email: String.t(),
          password: String.t()
        }

  @spec create_session(
          context :: any(),
          client_id :: String.t(),
          authentication_params :: authentication_params(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientimpl create_session(context, client_id, authentication_params, module) do
    with {:ok, user} <- apply(client_impl, :get_user, [authentication_params]),
         {:ok, user} <-
           apply(client_impl, :check_user_against, [user, authentication_params]),
         {:ok, session_token} <- apply(client_impl, :create_session, [user]) do
      module.user_authenticated(context, user, session_token)
    else
      {:error, _reason} ->
        module.authentication_failure(context, %SessionError{
          message: "Invalid email or password."
        })
    end
  end

  @type user_params :: %{
          email: String.t()
        }

  @callback get_user(user_params :: user_params()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @callback check_user_against(user :: User.t(), authentication_params :: authentication_params()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  # TODO move that function out of internal secondary port (bor-156)
  @callback create_session(user :: User.t()) ::
              {:ok, session_token :: String.t()} | {:error, changeset :: Ecto.Changeset.t()}

  @spec delete_session(
          context :: any(),
          client_id :: String.t(),
          session_token :: String.t(),
          module :: atom()
        ) ::
          callback_result :: any()
  defwithclientimpl delete_session(context, client_id, session_token, module) do
    case apply(client_impl, :delete_session, [session_token]) do
      :ok ->
        module.session_deleted(context)

      {:error, "Session not found."} ->
        module.session_deleted(context)
    end
  end

  # TODO move that function out of internal secondary port (bor-156)
  @callback(delete_session(session_token :: String.t()) :: :ok, {:error, String.t()})

  ## WIP Reset password

  defmodule ResetPasswordError do
    @enforce_keys [:message]
    defexception [:message, :changeset]

    @type t :: %__MODULE__{
            message: String.t(),
            changeset: Ecto.Changeset.t() | nil
          }

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message}
    end

    def message(exception) do
      exception.message
    end
  end

  defmodule ResetPasswordApplication do
    @moduledoc """
    TODO SessionApplication documentation
    """

    @callback reset_password_instructions_delivered(context :: any()) ::
                any()

    @callback invalid_relying_party(
                context :: any(),
                error :: RelyingPartyError.t()
              ) :: any()
  end

  @type reset_password_url_fun :: (token :: String.t() -> reset_password_url :: String.t())

  @spec send_reset_password_instructions(
          context :: any(),
          client_id :: String.t(),
          user_params :: user_params(),
          reset_password_url_fun :: reset_password_url_fun(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientimpl send_reset_password_instructions(
                      context,
                      client_id,
                      user_params,
                      reset_password_url_fun,
                      module
                    ) do
    with {:ok, user} <- apply(client_impl, :get_user, [user_params]) do
      apply(client_impl, :send_reset_password_instructions, [user, reset_password_url_fun])
    end

    # NOTE return a success either reset passowrd instructions email sent or not
    module.reset_password_instructions_delivered(context)
  end

  @callback send_reset_password_instructions(
              user :: User.t(),
              reset_password_url_fun :: reset_password_url_fun()
            ) ::
              :ok | {:error, reason :: String.t()}

  ## Deprecated Sessions

  @deprecated "prefer using `Accounts` use cases"
  defdelegate generate_user_session_token(user), to: Sessions

  ## Database getters

  defdelegate list_users, to: Users
  defdelegate get_user(id), to: Users
  defdelegate get_user_by_email(email), to: Users
  defdelegate check_user_password(user, password), to: Users
  defdelegate get_user_by_session_token(token), to: Users
  defdelegate get_user_by_reset_password_token(token), to: Users
  defdelegate get_user_scopes(user_id), to: Users

  ## User settings

  defdelegate update_user_password(user, password, attrs), to: Registrations
  defdelegate change_user_password(user), to: Registrations
  defdelegate change_user_password(user, attrs), to: Registrations
  defdelegate reset_user_password(user, attrs), to: Registrations
  defdelegate update_user_authorized_scopes(user, scopes), to: Registrations
  defdelegate change_user_email(user), to: Registrations
  defdelegate change_user_email(user, attrs), to: Registrations
  defdelegate apply_user_email(user, password, attrs), to: Registrations
  defdelegate update_user_email(user, token), to: Registrations
  defdelegate delete_user(id), to: Registrations

  ## Delivery

  defdelegate deliver_update_email_instructions(user, current_email, update_email_url_fun),
    to: Deliveries

  defdelegate deliver_user_confirmation_instructions(user, confirmation_url_fun), to: Deliveries

  @deprecated "prefer using `Accounts` use cases"
  defdelegate deliver_user_reset_password_instructions(user, reset_password_url_fun),
    to: Deliveries

  ## Confirmation

  defdelegate confirm_user(token), to: Confirmations

  ## Consent
  defdelegate consent(user, attrs), to: Consents
  defdelegate consented?(user, conn), to: Consents
  defdelegate consented_scopes(user, conn), to: Consents
end
