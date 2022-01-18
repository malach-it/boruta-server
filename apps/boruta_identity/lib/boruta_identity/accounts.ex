defmodule BorutaIdentity.Accounts.Utils do
  @moduledoc false

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  @spec client_relying_party(client_id :: String.t() | nil) ::
          {:ok, relying_party :: RelyingParty.t()} | {:error, reason :: String.t()}
  def client_relying_party(nil), do: {:error, "Client identifier not provided."}

  def client_relying_party(client_id) do
    case RelyingParties.get_relying_party_by_client_id(client_id) do
      %RelyingParty{} = relying_party ->
        {:ok, relying_party}

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
  defmacro defwithclientrp(fun, do: block) do
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
        with {:ok, relying_party} <- BorutaIdentity.Accounts.Utils.client_relying_party(unquote(client_id_param)),
             :ok <- BorutaIdentity.RelyingParties.RelyingParty.check_feature(relying_party, unquote(name)) do
            var!(client_rp) = relying_party

            unquote(block)
        else
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

defmodule BorutaIdentity.Accounts.RelyingPartyError do
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

defmodule BorutaIdentity.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias BorutaIdentity.Accounts.Confirmations
  alias BorutaIdentity.Accounts.Consents
  alias BorutaIdentity.Accounts.Deliveries
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

  defdelegate send_reset_password_instructions(
                context,
                client_id,
                reset_password_params,
                reset_password_url_fun,
                module
              ),
              to: ResetPasswords

  defdelegate initialize_password_reset(context, client_id, token, module), to: ResetPasswords

  defdelegate reset_password(context, client_id, reset_password_params, module), to: ResetPasswords

  ## WIP Confirmation

  defdelegate deliver_user_confirmation_instructions(user, confirmation_url_fun), to: Deliveries
  defdelegate confirm_user(token), to: Confirmations

  ## Deprecated Sessions

  defdelegate generate_user_session_token(user), to: Sessions

  ## Database getters

  defdelegate list_users, to: Users
  defdelegate get_user(id), to: Users
  defdelegate get_user_by_email(email), to: Users
  defdelegate get_user_by_session_token(token), to: Users
  defdelegate get_user_scopes(user_id), to: Users

  ## User settings

  defdelegate update_user_password(user, password, attrs), to: Settings
  defdelegate change_user_password(user), to: Settings
  defdelegate change_user_password(user, attrs), to: Settings
  defdelegate update_user_authorized_scopes(user, scopes), to: Settings
  defdelegate change_user_email(user), to: Settings
  defdelegate change_user_email(user, attrs), to: Settings
  defdelegate apply_user_email(user, password, attrs), to: Settings
  defdelegate update_user_email(user, token), to: Settings
  defdelegate delete_user(id), to: Settings
  defdelegate deliver_update_email_instructions(user, current_email, update_email_url_fun),
    to: Deliveries

  ## Consent
  defdelegate consent(user, attrs), to: Consents
  defdelegate consented?(user, conn), to: Consents
  defdelegate consented_scopes(user, conn), to: Consents
end
