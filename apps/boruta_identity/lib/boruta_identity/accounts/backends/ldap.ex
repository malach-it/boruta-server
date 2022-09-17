defmodule BorutaIdentity.Accounts.Ldap do
  @moduledoc false

  use GenServer

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.LdapRepo
  alias BorutaIdentity.Repo

  @behaviour BorutaIdentity.Accounts.Sessions

  @features [
    :authenticable
  ]

  def features, do: @features

  def start_link(backend) do
    GenServer.start_link(__MODULE__, backend, name: __MODULE__)
  end

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(backend, user_params) do
    GenServer.call(__MODULE__, {:get_user, backend, user_params})
  end

  @impl BorutaIdentity.Accounts.Sessions
  def domain_user!(%Ldap.User{uid: uid, username: username}, %Backend{id: backend_id}) do
    User.implementation_changeset(%{
      uid: uid,
      username: username,
      backend_id: backend_id
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:username]},
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend])
  end

  @impl BorutaIdentity.Accounts.Sessions
  def check_user_against(backend, ldap_user, authentication_params) do
    GenServer.call(__MODULE__, {:check_user_against, backend, ldap_user, authentication_params})
  end

  @impl GenServer
  def init(backend) do
    # TODO add ldap port configuration
    {:ok, ldap} = LdapRepo.open(backend.ldap_host)

    {:ok, %{ldap: ldap}}
  end

  @impl GenServer
  def handle_call({:get_user, backend, %{email: email}}, _from, %{ldap: ldap} = state) do
    {:reply, get_user_from_ldap(ldap, backend, email), state}
  end

  def handle_call(
        {:check_user_against, _backend, %Ldap.User{dn: dn} = user, authentication_params},
        _from,
        %{ldap: ldap} = state
      ) do
    result =
      with :ok <- LdapRepo.simple_bind(ldap, dn, authentication_params[:password]) do
        {:ok, user}
      end

    {:reply, result, state}
  end

  defp get_user_from_ldap(ldap, backend, email) do
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
end
