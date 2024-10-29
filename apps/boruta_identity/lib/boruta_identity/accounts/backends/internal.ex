defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """

  @behaviour BorutaIdentity.Admin
  @behaviour BorutaIdentity.Accounts.Registrations
  @behaviour BorutaIdentity.Accounts.ResetPasswords
  @behaviour BorutaIdentity.Accounts.Sessions
  @behaviour BorutaIdentity.Accounts.Settings

  import Ecto.Query, only: [from: 2]

  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @features [
    :authenticable,
    :totpable,
    :webauthnable,
    :registrable,
    :user_editable,
    :confirmable,
    :reset_password,
    :consentable
  ]

  def features, do: @features

  @account_type "internal"

  def account_type, do: @account_type

  @impl BorutaIdentity.Accounts.Registrations
  def register(backend, registration_params) do
    with {:ok, user} <-
           Internal.User.registration_changeset(
             %Internal.User{
               group: registration_params[:group],
               metadata: registration_params[:metadata]
             },
             registration_params,
             %{
               backend: backend
             }
           )
           |> Repo.insert() do
      {:ok, domain_user!(user, backend)}
    end
  end

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(backend, %{email: email}) when is_binary(email) do
    user = Repo.get_by!(Internal.User, email: email, backend_id: backend.id)

    {:ok, user}
  rescue
    Ecto.NoResultsError ->
      {:error, "User not found."}
  end

  def get_user(_authentication_params), do: {:error, "Cannot find an user without an email."}

  @impl BorutaIdentity.Accounts.Sessions
  def domain_user!(
        %Internal.User{id: id, email: email, metadata: metadata, group: group},
        %Backend{
          id: backend_id
        } = backend
      ) do
    impl_user_params = %{
      uid: id,
      username: email,
      group: group,
      backend_id: backend_id,
      account_type: @account_type
    }

    {replace, impl_user_params} =
      case metadata do
        %{} = metadata ->
          {[:username, :metadata, :group], Map.put(impl_user_params, :metadata, metadata)}

        _ ->
          {[:username, :group], impl_user_params}
      end

    User.implementation_changeset(impl_user_params, backend)
    |> Repo.insert!(
      on_conflict: {:replace, replace},
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end

  # BorutaIdentity.Accounts.Sessions, BorutaIdentity.Accounts.Settings
  @impl true
  def check_user_against(backend, user, authentication_params) do
    check_user_password(backend, user, authentication_params[:password])
  end

  defp check_user_password(backend, user, password) do
    case Internal.User.valid_password?(backend, user, password) do
      true -> {:ok, user}
      false -> {:error, "Invalid user password."}
    end
  end

  @impl BorutaIdentity.Accounts.ResetPasswords
  def reset_password(backend, reset_password_params) do
    with {:ok, user} <-
           get_user_by_reset_password_token(reset_password_params.reset_password_token),
         {:ok, %{user: user}} <- reset_user_password_multi(backend, user, reset_password_params) do
      {:ok, user}
    else
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, _reason} = error -> error
    end
  end

  @impl BorutaIdentity.Accounts.Settings
  def update_user(backend, user, params) do
    # TODO database transaction
    with {:ok, user} <-
           %{user | metadata: params[:metadata], group: params[:group]}
           |> Internal.User.update_changeset(params, %{backend: backend})
           |> Repo.update() do
      {:ok, domain_user!(user, backend)}
    end
  end

  @impl BorutaIdentity.Admin
  def create_user(backend, params) do
    # TODO database transaction
    with {:ok, user} <-
           Internal.User.registration_changeset(
             %Internal.User{
               group: params[:group],
               metadata: params[:metadata]
             },
             %{
               email: params[:username],
               password: params[:password]
             },
             %{backend: backend}
           )
           |> Repo.insert() do
      {:ok, domain_user!(user, backend)}
    end
  end

  @impl BorutaIdentity.Admin
  def create_raw_user(backend, params) do
    # TODO database transaction
    with {:ok, user} <-
           Internal.User.raw_registration_changeset(
             %Internal.User{},
             %{
               email: params[:username],
               hashed_password: params[:hashed_password]
             },
             %{backend: backend}
           )
           |> Repo.insert() do
      {:ok, domain_user!(user, backend)}
    end
  end

  @impl BorutaIdentity.Admin
  def delete_user(uid) do
    case Repo.delete_all(from(u in Internal.User, where: u.id == ^uid)) do
      {1, nil} -> :ok
      _ -> {:error, "User could not be deleted."}
    end
  end

  defp get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query),
         %Internal.User{} = user <- Repo.get(Internal.User, user.uid) do
      {:ok, user}
    else
      _ -> {:error, "Given reset password token is invalid."}
    end
  end

  defp reset_user_password_multi(backend, user, reset_password_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :user,
      Internal.User.password_changeset(user, reset_password_params, %{backend: backend})
    )
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
  end
end
