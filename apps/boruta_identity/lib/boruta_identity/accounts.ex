defmodule BorutaIdentity.Accounts.Utils do
  @moduledoc false

  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @spec client_identity_provider(client_id :: String.t() | nil) ::
          {:ok, identity_provider :: IdentityProvider.t()} | {:error, reason :: String.t()}
  def client_identity_provider(nil), do: {:error, "Client identifier not provided."}

  def client_identity_provider(client_id) do
    case IdentityProviders.get_identity_provider_by_client_id(client_id) do
      %IdentityProvider{} = identity_provider ->
        {:ok, identity_provider}

      nil ->
        {:error,
         "identity provider not configured for given OAuth client. Please contact your administrator."}
    end
  end

  @doc """
  Adds `client_impl` variable in function body context. The function definition must have
  `context`, `client_id` and `module' as parameters.
  """
  # TODO find a better way to delegate to the given client idp
  defmacro defwithclientidp(fun, do: block) do
    fun = Macro.escape(fun, unquote: true)
    block = Macro.escape(block, unquote: true)

    quote bind_quoted: [fun: fun, block: block] do
      {name, params} = Macro.decompose_call(fun)

      context_param =
        Enum.find(params, fn {var, _, _} -> var == :context end) ||
          raise "`context` must be part of function parameters"

      client_id_param =
        Enum.find(params, fn {var, _, _} -> var == :client_id end) ||
          raise "`client_id` must be part of function parameters"

      module_param =
        Enum.find(params, fn {var, _, _} -> var == :module end) ||
          raise "`module` must be part of function parameters"

      def unquote({name, [line: __ENV__.line], params}) do
        with {:ok, identity_provider} <-
               BorutaIdentity.Accounts.Utils.client_identity_provider(unquote(client_id_param)),
             :ok <-
               BorutaIdentity.IdentityProviders.IdentityProvider.check_feature(
                 identity_provider,
                 unquote(name)
               ) do
          var!(client_idp) = identity_provider

          unquote(block)
        else
          {:error, reason} ->
            raise BorutaIdentity.Accounts.IdentityProviderError, reason
        end
      end
    end
  end
end

defmodule BorutaIdentity.Accounts.IdentityProviderError do
  @enforce_keys [:message]
  defexception [:message, plug_status: 400]

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

defmodule BorutaIdentity.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias BorutaIdentity.Accounts.ChooseSessions
  alias BorutaIdentity.Accounts.Confirmations
  alias BorutaIdentity.Accounts.Consents
  alias BorutaIdentity.Accounts.Registrations
  alias BorutaIdentity.Accounts.ResetPasswords
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.Accounts.Settings
  alias BorutaIdentity.Accounts.Users

  ## Registrations

  defdelegate initialize_registration(context, client_id, module), to: Registrations
  defdelegate register(context, client_id, registration_params, confirmation_url_fun, module),
    to: Registrations

  ## Sessions

  defdelegate initialize_session(context, client_id, module), to: Sessions
  defdelegate create_session(context, client_id, authentication_params, module), to: Sessions
  defdelegate delete_session(context, client_id, session_token, module), to: Sessions

  ## Reset passwords

  defdelegate initialize_password_instructions(context, client_id, module), to: ResetPasswords
  defdelegate send_reset_password_instructions(
                context,
                client_id,
                reset_password_params,
                reset_password_url_fun,
                module
              ),
              to: ResetPasswords

  defdelegate initialize_password_reset(context, client_id, token, module), to: ResetPasswords
  defdelegate reset_password(context, client_id, reset_password_params, module),
    to: ResetPasswords

  ## Confirmation

  defdelegate initialize_confirmation_instructions(context, client_id, module), to: Confirmations
  defdelegate send_confirmation_instructions(
                context,
                confirmation_params,
                confirmation_url_fun,
                module
              ),
              to: Confirmations
  defdelegate confirm_user(context, client_id, token, module), to: Confirmations

  ## Consent

  defdelegate initialize_consent(context, client_id, user, scope, module), to: Consents
  defdelegate consent(context, client_id, user, params, module), to: Consents

  ## Choose session

  defdelegate initialize_choose_session(context, client_id, module), to: ChooseSessions

  ## User settings

  defdelegate initialize_edit_user(context, client_id, user, module), to: Settings
  defdelegate update_user(context, client_id, user, params, confirmation_url_fun, module), to: Settings

  ## Deprecated Database getters

  defdelegate get_user(id), to: Users
  defdelegate get_user_by_email(email), to: Users
  defdelegate get_user_by_session_token(token), to: Users
  defdelegate get_user_scopes(user_id), to: Users
end
