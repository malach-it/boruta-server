defmodule BorutaIdentity.LdapRepo do
  @moduledoc false

  alias BorutaIdentity.IdentityProviders.Backend

  @type user_properties :: %{
          String.t() => list(String.t())
        }

  @callback open(host :: String.t()) :: {:ok, pid()}
  @callback open(host :: String.t(), opts :: Keyword.t()) :: {:ok, pid()}
  @callback simple_bind(handle :: pid(), dn :: String.t(), password :: String.t()) ::
              :ok | {:error, any()}
  @callback search(handle :: pid, backend :: Backend.t(), email :: String.t()) ::
              {:ok, {dn :: String.t(), user_properties :: user_properties()}} | {:error, any()}

  def open(host, opts \\ []), do: impl().open(host, opts)

  def simple_bind(handle, dn, password), do: impl().simple_bind(handle, dn, password)

  def search(handle, backend, email), do: impl().search(handle, backend, email)

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

  @impl BorutaIdentity.LdapRepo
  def open(host, opts \\ []) do
    :eldap.open([String.to_charlist(host)], opts)
  end

  @impl BorutaIdentity.LdapRepo
  def simple_bind(handle, dn, password) do
    :eldap.simple_bind(handle, String.to_charlist(dn), password)
  end

  @impl BorutaIdentity.LdapRepo
  def search(handle, backend, email) do
    user_rdn_attribute = String.to_charlist(backend.ldap_user_rdn_attribute)

    case :eldap.search(handle,
           base: backend.ldap_base_dn,
           filter: :eldap.equalityMatch(user_rdn_attribute, String.to_charlist(email))
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
end
