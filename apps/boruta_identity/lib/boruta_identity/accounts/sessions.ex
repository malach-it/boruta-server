defmodule BorutaIdentity.Accounts.SessionError do
  @enforce_keys [:message]
  defexception [:message, :changeset, :template]

  @type t :: %__MODULE__{
          message: String.t(),
          changeset: Ecto.Changeset.t() | nil,
          template: BorutaIdentity.RelyingParties.Template.t()
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaIdentity.Accounts.SessionApplication do
  @moduledoc """
  TODO SessionApplication documentation
  """

  @callback session_initialized(
              context :: any(),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

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

  @callback session_deleted(context :: any()) :: any()
end

defmodule BorutaIdentity.Accounts.Sessions do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.Repo

  @type user_params :: %{
          email: String.t()
        }

  @type authentication_params :: %{
          email: String.t(),
          password: String.t()
        }

  @callback get_user(user_params :: user_params()) ::
              {:ok, implmentation_user :: any()} | {:error, reason :: String.t()}

  @callback domain_user!(implementation_user :: any()) ::
              user :: User.t()

  @callback check_user_against(
              user :: User.t(),
              authentication_params :: authentication_params()
            ) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @spec initialize_session(
          context :: any(),
          client_id :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_session(context, client_id, module) do
    module.session_initialized(context, new_session_template(client_rp))
  end

  @spec create_session(
          context :: any(),
          client_id :: String.t(),
          authentication_params :: authentication_params(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp create_session(context, client_id, authentication_params, module) do
    client_impl = RelyingParty.implementation(client_rp)

    with {:ok, user} <- apply(client_impl, :get_user, [authentication_params]),
         {:ok, user} <-
           apply(client_impl, :check_user_against, [user, authentication_params]),
         %User{} = user <- apply(client_impl, :domain_user!, [user]),
         :ok <- ensure_user_confirmed(user, client_rp),
         {:ok, user, session_token} <- create_user_session(user) do
      module.user_authenticated(context, user, session_token)
    else
      {:error, _reason} ->
        module.authentication_failure(context, %SessionError{
          template: new_session_template(client_rp),
          message: "Invalid email or password."
        })

      {:user_not_confirmed, reason} ->
        module.authentication_failure(context, %SessionError{
          template: new_confirmation_instructions_template(client_rp),
          message: reason
        })
    end
  end

  # TODO have a look to OpenID logout profile
  @spec delete_session(
          context :: any(),
          client_id :: String.t(),
          session_token :: String.t(),
          module :: atom()
        ) ::
          callback_result :: any()
  def delete_session(context, _client_id, session_token, module) do
    case delete_session(session_token) do
      :ok ->
        module.session_deleted(context)

      {:error, "Session not found."} ->
        module.session_deleted(context)
    end
  end

  @spec create_user_session(user :: User.t()) ::
          {:ok, user :: User.t(), session_token :: String.t()}
          | {:error, changeset :: Ecto.Changeset.t()}
  def create_user_session(%User{} = user) do
    with {_token, user_token} <- UserToken.build_session_token(user),
         {:ok, session_token} <- Repo.insert(user_token) do
      {:ok, user, session_token.token}
    end
  end

  defp ensure_user_confirmed(_user, %RelyingParty{confirmable: false}), do: :ok

  defp ensure_user_confirmed(user, %RelyingParty{confirmable: true}) do
    case User.confirmed?(user) do
      true -> :ok
      false -> {:user_not_confirmed, "Email confirmation is required to authenticate."}
    end
  end

  defp new_session_template(relying_party) do
    RelyingParties.get_relying_party_template!(relying_party.id, :new_session)
  end

  defp new_confirmation_instructions_template(relying_party) do
    RelyingParties.get_relying_party_template!(relying_party.id, :new_confirmation_instructions)
  end

  defp delete_session(nil), do: {:error, "Session not found."}

  defp delete_session(session_token) do
    case Repo.delete_all(UserToken.token_and_context_query(session_token, "session")) do
      {1, _} -> :ok
      {_, _} -> {:error, "Session not found."}
    end
  end
end
