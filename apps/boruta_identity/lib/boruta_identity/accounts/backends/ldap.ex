defmodule BorutaIdentity.Accounts.Ldap do
  @moduledoc false

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @behaviour BorutaIdentity.Accounts.Sessions

  @features [
    :authenticable
  ]

  def features, do: @features

  @impl BorutaIdentity.Accounts.Sessions
  def get_user(backend, %{email: email}) do
    # TODO configure user attribute in backend schema
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)
    # TODO store ldap connection in a GenServer
    {:ok, ldap} = :eldap.open([String.to_charlist(backend.ldap_host)])

    with {:ok,
          {:eldap_search_result,
           [
             {:eldap_entry, dn, user_properties}
           ], _,
           _}} <-
           :eldap.search(ldap,
             base: backend.ldap_base_dn,
             filter: :eldap.equalityMatch(user_rdn_attribute, String.to_charlist(email))
           ),
         {'uid', [uid]} <-
           Enum.find(
             user_properties,
             {:error, "Could not get uid attribute"},
             fn {property, _value} ->
               property == 'uid'
             end
           ),
         {^user_rdn_attribute, [username]} <-
           Enum.find(
             user_properties,
             {:error, "Could not get username (#{user_rdn_attribute}) attribute"},
             fn {property, _value} ->
               property == user_rdn_attribute
             end
           ) do
      {:ok,
       %Ldap.User{
         uid: to_string(uid),
         dn: to_string(dn),
         username: to_string(username),
         backend: backend
       }}
    else
      {:ok, {:eldap_search_result, _results, _, _}} ->
        {:error, "Multiple users matched the given #{user_rdn_attribute}."}

      {:error, error} when is_binary(error) ->
        {:error, error}

      {:error, error} ->
        {:error, inspect(error)}
    end
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
  def check_user_against(backend, %Ldap.User{dn: dn} = user, %{password: password}) do
    {:ok, ldap} = :eldap.open([String.to_charlist(backend.ldap_host)])

    with :ok <- :eldap.simple_bind(ldap, dn, password) do
      {:ok, user}
    end
  end
end
