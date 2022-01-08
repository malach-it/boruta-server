defmodule BorutaIdentity.Accounts.SessionError do
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

defmodule BorutaIdentity.Accounts.SessionApplication do
  @moduledoc """
  TODO SessionApplication documentation
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

  @callback session_deleted(context :: any()) :: any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Sessions do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientimpl: 2]

  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.Repo

  @callback get_user(user_params :: user_params()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  @callback check_user_against(user :: User.t(), authentication_params :: authentication_params()) ::
              {:ok, user :: User.t()} | {:error, reason :: String.t()}

  # TODO move that function out of internal secondary port (bor-156)
  @callback create_session(user :: User.t()) ::
              {:ok, session_token :: String.t()} | {:error, changeset :: Ecto.Changeset.t()}

  # TODO move that function out of internal secondary port (bor-156)
  @callback delete_session(session_token :: String.t()) :: :ok | {:error, String.t()}

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

  @doc """
  Generates a session token.
  """
  @deprecated "deprecated in `BorutaIdentity.Accounts` interface"
  @spec generate_user_session_token(user :: User.t()) :: token :: String.t()
  def generate_user_session_token(user) do
    User.login_changeset(user) |> Repo.update()

    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end
end
