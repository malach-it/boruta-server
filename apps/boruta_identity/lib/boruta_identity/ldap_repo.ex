defmodule BorutaIdentity.LdapRepo do
  @moduledoc false

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders.Backend

  @type user_properties :: %{
          String.t() => list(String.t())
        }

  @callback open(host :: String.t()) :: {:ok, pid()} | {:error, reason :: any()}
  @callback open(host :: String.t(), opts :: Keyword.t()) ::
              {:ok, pid()} | {:error, reason :: any()}
  @callback close(handle :: pid()) :: :ok
  @callback simple_bind(handle :: pid(), dn :: String.t(), password :: String.t()) ::
              :ok | {:error, any()}
  @callback search(handle :: pid, backend :: Backend.t(), username :: String.t()) ::
              {:ok, {dn :: String.t(), user_properties :: user_properties()}} | {:error, any()}
  @callback modify(
              handle :: pid,
              backend :: Backend.t(),
              user :: Ldap.User.t(),
              username :: String.t()
            ) ::
              :ok | {:error, any()}
  @callback modify_password(
              handle :: pid,
              user :: Ldap.User.t(),
              new_password :: String.t(),
              old_password :: String.t()
            ) ::
              :ok | {:error, any()}
  @callback modify_password(
              handle :: pid,
              user :: Ldap.User.t(),
              new_password :: String.t()
            ) ::
              :ok | {:error, any()}

  def open(host, opts \\ []), do: impl().open(host, opts)

  def close(handle), do: impl().close(handle)

  def simple_bind(handle, dn, password), do: impl().simple_bind(handle, dn, password)

  def search(handle, backend, username), do: impl().search(handle, backend, username)

  def modify(handle, backend, user, username), do: impl().modify(handle, backend, user, username)

  def modify_password(handle, user, new_password, old_password),
    do: impl().modify_password(handle, user, new_password, old_password)

  def modify_password(handle, user, new_password),
    do: impl().modify_password(handle, user, new_password)

  defp impl do
    case Application.get_env(:boruta_identity, BorutaIdentity.LdapRepo) do
      [adapter: adapter] ->
        adapter

      _ ->
        BorutaIdentity.LdapAdapter
    end
  end
end

defmodule BorutaIdentity.LdapAdapter do
  @moduledoc false

  @behaviour BorutaIdentity.LdapRepo

  alias BorutaIdentity.Accounts.Ldap

  @impl BorutaIdentity.LdapRepo
  def open(host, opts \\ []) do
    :eldap.open([String.to_charlist(host)], opts)
  end

  @impl BorutaIdentity.LdapRepo
  def close(handle) do
    :eldap.close(handle)
  end

  @impl BorutaIdentity.LdapRepo
  def simple_bind(handle, dn, password) do
    :eldap.simple_bind(handle, String.to_charlist(dn), password)
  rescue
    _ -> {:error, "Authentication failed."}
  end

  @impl BorutaIdentity.LdapRepo
  def search(handle, backend, username) do
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)

    base_dn =
      [backend.ldap_ou, backend.ldap_base_dn]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(",")

    case :eldap.search(handle,
           base: base_dn,
           filter: :eldap.equalityMatch(user_rdn_attribute, String.to_charlist(username))
         ) do
      {:ok,
       {:eldap_search_result,
        [
          {:eldap_entry, dn, user_properties}
        ], _, _}} ->
        user_properties =
          Enum.map(user_properties, fn {key, values} ->
            {to_string(key), List.first(values) |> to_string()}
          end)
          |> Enum.into(%{})

        {:ok, {to_string(dn), user_properties}}

      {:ok, {:eldap_search_result, _results, _, _}} ->
        {:error, "Multiple users matched the given #{user_rdn_attribute}."}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl BorutaIdentity.LdapRepo
  def modify(handle, backend, %Ldap.User{dn: dn}, username) do
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)
    username = String.to_charlist(username)

    :eldap.modify(handle, String.to_charlist(dn), [
      :eldap.mod_replace(user_rdn_attribute, [username])
    ])
  end

  @impl BorutaIdentity.LdapRepo
  def modify_password(handle, %Ldap.User{dn: dn}, new_password, old_password)
      when byte_size(new_password) > 0 do
    :eldap.modify_password(
      handle,
      String.to_charlist(dn),
      String.to_charlist(new_password),
      String.to_charlist(old_password)
    )
  end

  @impl BorutaIdentity.LdapRepo
  def modify_password(handle, %Ldap.User{dn: dn}, new_password)
      when byte_size(new_password) > 0 do
    :eldap.modify_password(
      handle,
      String.to_charlist(dn),
      String.to_charlist(new_password)
    )
  end
end
