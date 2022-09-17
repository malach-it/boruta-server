defmodule BorutaIdentity.Accounts.Ldap do
  @moduledoc false

  use GenServer

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
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
    {:ok, ldap} = :eldap.open([String.to_charlist(backend.ldap_host)])

    {:ok, %{ldap: ldap}}
  end

  @impl GenServer
  def handle_call({:get_user, backend, %{email: email}}, _from, %{ldap: ldap} = state) do
    {:reply, get_user_from_ldap(ldap, backend, email), state}
  end

  def handle_call(
        {:check_user_against, _backend, %Ldap.User{dn: dn} = user, %{password: password}},
        _from,
        %{ldap: ldap} = state
      ) do
    result =
      with :ok <- :eldap.simple_bind(ldap, dn, password) do
        {:ok, user}
      end

    {:reply, result, state}
  end

  defp get_user_from_ldap(ldap, backend, email) do
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)

    with {:ok, {dn, user_properties}} <- search(ldap, backend, email),
         {:ok, uid} <- fetch_from_user_properties(user_properties, 'uid'),
         {:ok, username} <- fetch_from_user_properties(user_properties, user_rdn_attribute) do
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

  defp search(ldap, backend, email) do
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)

    case :eldap.search(ldap,
           base: backend.ldap_base_dn,
           filter: :eldap.equalityMatch(user_rdn_attribute, String.to_charlist(email))
         ) do
      {:ok,
       {:eldap_search_result,
        [
          {:eldap_entry, dn, user_properties}
        ], _, _}} ->
        {:ok, {dn, user_properties}}

      {:ok, {:eldap_search_result, _results, _, _}} ->
        {:error, "Multiple users matched the given #{user_rdn_attribute}."}
    end
  end

  defp fetch_from_user_properties(user_properties, key) do
    case Enum.find(
           user_properties,
           fn {property, _value} ->
             property == key
           end
         ) do
      nil ->
        {:error, "Could not get uid attribute"}

      {^key, [uid]} ->
        {:ok, uid}
    end
  end
end
