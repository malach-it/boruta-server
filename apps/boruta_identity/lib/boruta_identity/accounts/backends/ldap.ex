defmodule BorutaIdentity.Accounts.LdapError do
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

defmodule BorutaIdentity.Accounts.Ldap do
  @moduledoc false

  @behaviour NimblePool

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.Accounts.LdapError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.LdapRepo
  alias BorutaIdentity.Repo

  @behaviour BorutaIdentity.Accounts.ResetPasswords
  @behaviour BorutaIdentity.Accounts.Sessions
  @behaviour BorutaIdentity.Accounts.Settings
  @behaviour BorutaIdentity.Admin

  @features [
    :authenticable,
    :totpable,
    :webauthnable,
    :consentable,
    :user_editable,
    :reset_password,
    :confirmable
  ]

  @account_type "ldap"

  def account_type, do: "ldap"

  @ldap_timeout 10_000

  def features, do: @features

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(backend, %{email: email}) do
    lazy_start(backend)

    NimblePool.checkout!(
      pool_name(backend),
      :checkout,
      fn _from, ldap ->
        {fetch_user_from_ldap(ldap, backend, email), ldap}
      end,
      @ldap_timeout
    )
  end

  @impl BorutaIdentity.Accounts.Sessions
  def domain_user!(
        %Ldap.User{uid: uid, username: username, metadata: metadata},
        %Backend{id: backend_id} = backend
      ) do
    impl_user_params = %{
      uid: uid,
      username: username,
      backend_id: backend_id,
      account_type: @account_type
    }

    {replace, impl_user_params} =
      case metadata do
        %{} = metadata ->
          {[:username, :metadata], Map.put(impl_user_params, :metadata, metadata)}

        _ ->
          {[:username], impl_user_params}
      end

    User.implementation_changeset(impl_user_params, backend)
    |> Repo.insert!(
      on_conflict: {:replace, replace},
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end

  @impl BorutaIdentity.Accounts.Sessions
  def check_user_against(backend, ldap_user, authentication_params) do
    lazy_start(backend)

    NimblePool.checkout!(
      pool_name(backend),
      :checkout,
      fn _from, ldap ->
        case LdapRepo.simple_bind(ldap, ldap_user.dn, authentication_params[:password]) do
          :ok ->
            {{:ok, ldap_user}, ldap}

          _error ->
            {{:error, "Authentication failure."}, ldap}
        end
      end,
      @ldap_timeout
    )
  end

  @impl BorutaIdentity.Accounts.Settings
  def update_user(backend, user, params) do
    lazy_start(backend)

    NimblePool.checkout!(
      pool_name(backend),
      :checkout,
      fn _from, ldap ->
        case update_user_in_ldap(ldap, backend, user, params) do
          {:ok, user} ->
            {{:ok, domain_user!(%{user | metadata: params[:metadata]}, backend)}, ldap}

          {:error, error, user} ->
            # NOTE keep user synchronized from LDAP
            domain_user!(user, backend)

            {{:error, error}, ldap}
        end
      end
    )
  end

  @impl BorutaIdentity.Accounts.Settings
  def delete_user(_id) do
    {:error, "LDAP backends does not support user deletion."}
  end

  @impl BorutaIdentity.Accounts.ResetPasswords
  def reset_password(backend, reset_password_params) do
    lazy_start(backend)

    NimblePool.checkout!(
      pool_name(backend),
      :checkout,
      fn _from, ldap ->
        with {:ok, user} <-
               get_user_by_reset_password_token(
                 ldap,
                 backend,
                 reset_password_params.reset_password_token
               ),
             {:ok, _user} <- reset_password_in_ldap(ldap, backend, user, reset_password_params) do
          {{:ok, user}, ldap}
        else
          {:error, error} ->
            {{:error, error}, ldap}
        end
      end
    )
  end

  @impl BorutaIdentity.Admin
  def create_user(_backend, _params) do
    raise LdapError, "LDAP backends does not support user creation."
  end

  @impl BorutaIdentity.Admin
  def create_raw_user(_backend, _params) do
    raise LdapError, "LDAP backends does not support user creation."
  end

  @spec pool_name(backend :: Backend.t()) :: pool_name :: atom()
  def pool_name(backend) do
    signature =
      backend
      |> Map.from_struct()
      |> Enum.map_join(fn
        {key, value} ->
          case Atom.to_string(key) do
            "ldap_" <> _rest -> to_string(value)
            _ -> nil
          end
      end)

    signature = :crypto.hash(:sha256, signature)

    signature
    |> Base.encode16()
    |> String.to_atom()
  end

  def start_link(backend) do
    NimblePool.start_link(
      pool_size: backend.ldap_pool_size,
      worker: {__MODULE__, %{backend: backend}},
      name: pool_name(backend)
    )
  end

  @impl NimblePool
  def init_worker(%{backend: backend}) do
    # TODO add ldap port and ssl configurations
    {:ok, ldap} = LdapRepo.open(backend.ldap_host)

    {:ok, ldap, %{backend: backend}}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, ldap, pool_state) do
    {:ok, ldap, ldap, pool_state}
  end

  @impl NimblePool
  def handle_checkin(ldap, _from, ldap, pool_state) do
    {:remove, :closed, pool_state}
  end

  @impl NimblePool
  def terminate_worker(_reason, ldap, pool_state) do
    LdapRepo.close(ldap)

    {:ok, pool_state}
  rescue
    _ ->
      {:ok, pool_state}
  end

  defp fetch_user_from_ldap(ldap, backend, email) do
    user_rdn_attribute = backend.ldap_user_rdn_attribute

    with {:ok, {dn, user_properties}} <- LdapRepo.search(ldap, backend, email),
         uid when is_binary(uid) <-
           Map.get(
             user_properties,
             "uid",
             {:error, "Could not get uid attribute"}
           ),
         username when is_binary(username) <-
           Map.get(
             user_properties,
             user_rdn_attribute,
             {:error, "Could not get #{user_rdn_attribute} attribute"}
           ) do
      {:ok,
       %Ldap.User{
         uid: to_string(uid),
         dn: to_string(dn),
         username: to_string(username),
         backend: backend
       }}
    else
      {:error, error} when is_binary(error) ->
        {:error, error}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  defp update_user_in_ldap(
         ldap,
         %Backend{
           ldap_master_dn: ldap_master_dn,
           ldap_master_password: ldap_master_password
         } = backend,
         user,
         %{email: email} = params
       ) do
    with :ok <- LdapRepo.simple_bind(ldap, ldap_master_dn, ldap_master_password),
         :ok <-
           LdapRepo.modify(ldap, backend, user, email) do
      user = %{user | username: to_string(email)}
      update_user_in_ldap(ldap, backend, user, Map.delete(params, :email))
    else
      {:error, error} ->
        {:error, error, user}
    end
  end

  defp update_user_in_ldap(
         ldap,
         backend,
         user,
         %{password: password, current_password: current_password} = params
       )
       when byte_size(password) > 0 do
    case LdapRepo.modify_password(ldap, user, password, current_password) do
      :ok ->
        update_user_in_ldap(ldap, backend, user, Map.delete(params, :password))

      {:error, error} ->
        {:error, error, user}
    end
  end

  defp update_user_in_ldap(_ldap, _backend, user, _params), do: {:ok, user}

  defp get_user_by_reset_password_token(ldap, backend, token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{username: username} <- Repo.one(query),
         {:ok, user} <- fetch_user_from_ldap(ldap, backend, username) do
      {:ok, user}
    else
      _ -> {:error, "Given reset password token is invalid."}
    end
  end

  defp reset_password_in_ldap(
         ldap,
         %Backend{
           ldap_master_dn: ldap_master_dn,
           ldap_master_password: ldap_master_password
         },
         user,
         %{password: password} = reset_password_params
       )
       when byte_size(password) > 0 do
    with :ok <- check_password_confirmation(reset_password_params),
         :ok <- LdapRepo.simple_bind(ldap, ldap_master_dn, ldap_master_password),
         :ok <- LdapRepo.modify_password(ldap, user, reset_password_params.password) do
      {:ok, user}
    end
  end

  defp reset_password_in_ldap(_ldap, _backend, _user, _reset_password_params),
    do: {:error, "Password cannot be empty."}

  defp check_password_confirmation(%{
         password: password,
         password_confirmation: password_confirmation
       })
       when password == password_confirmation do
    :ok
  end

  defp check_password_confirmation(_reset_password_params),
    do: {:error, "Password and password confirmation do not match."}

  defp lazy_start(backend) do
    case start_link(backend) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end
end
