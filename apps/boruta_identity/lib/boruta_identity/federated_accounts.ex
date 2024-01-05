defmodule BorutaIdentity.Accounts.FederatedSessionApplication do
  @moduledoc """
  TODO FederatedSessionApplication documentation
  """

  @callback user_authenticated(
              context :: any(),
              user :: BorutaIdentity.Accounts.User.t(),
              session_token :: String.t()
            ) ::
              any()

  @callback authentication_failure(
              context :: any(),
              error :: BorutaIdentity.Accounts.SessionError.t()
            ) ::
              any()
end

defmodule BorutaIdentity.FederatedAccounts do
  @moduledoc false
  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]

  alias BorutaIdentity.Accounts.Federated
  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend

  @callback domain_user!(
              federated_server_name :: String.t(),
              access_token :: String.t(),
              backend :: Backend.t()
            ) ::
              user :: User.t()

  @spec create_federated_session(
          context :: any(),
          client_id :: String.t(),
          federated_server_name :: any(),
          code :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp create_federated_session(
                     context,
                     client_id,
                     federated_server_name,
                     code,
                     module
                   ) do
    try do
      case Backend.federated_oauth_client(client_idp.backend, federated_server_name) do
        nil ->
          raise IdentityProviderError, "Could not fetch associated federated server."

        oauth_client ->
          %OAuth2.Client{token: token} =
            OAuth2.Client.get_token!(oauth_client, code: code)

          with %User{} = user <-
                 Federated.domain_user!(federated_server_name, token.access_token, client_idp.backend),
               {:ok, user, session_token} <- Sessions.create_user_session(user) do
            module.user_authenticated(context, user, session_token)
          end
      end
    rescue
    error in OAuth2.Error ->
        module.authentication_failure(context, %SessionError{
          message: error.reason,
          template: new_session_template(client_idp)
        })
    error in IdentityProviderError ->
        module.authentication_failure(context, %SessionError{
          message: error.message,
          template: new_session_template(client_idp)
        })
      error ->
        Logger.error("Federation failed " <> inspect(error))
        module.authentication_failure(context, %SessionError{
          message: "Could not fetch user information.",
          template: new_session_template(client_idp)
        })
    end
  end

  defp new_session_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_session)
  end
end
