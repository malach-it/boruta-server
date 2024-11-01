defmodule BorutaWeb.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  use BorutaIdentityWeb, :controller

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Scope
  alias BorutaFederation.FederationEntities
  alias BorutaFederation.TrustChains
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.VerifiableCredentials
  alias BorutaIdentity.Accounts.VerifiablePresentations
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Organizations.Organization

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username) do
    backend = Backend.default!()

    with {:ok, impl_user} <-
           apply(Backend.implementation(backend), :get_user, [backend, %{email: username}]),
         %User{id: id, username: email, last_login_at: last_login_at} <-
           apply(Backend.implementation(backend), :domain_user!, [impl_user, backend]) do
      {:ok,
       %ResourceOwner{
         sub: id,
         username: email,
         last_login_at: last_login_at,
         # TODO find out why the impl user in extra_claims
         extra_claims: %{user: impl_user}
       }}
    else
      _ ->
        {:error, "Invalid username or password."}
    end
  end

  def get_by(sub: sub, scope: scope) when not is_nil(sub) do
    case Accounts.get_user(sub) do
      %User{
        id: id,
        username: email,
        last_login_at: last_login_at,
        federated_metadata: federated_metadata
      } = user ->
        {:ok,
         %ResourceOwner{
           sub: id,
           username: email,
           last_login_at: last_login_at,
           extra_claims: Map.merge(metadata(user, scope), federated_metadata),
           authorization_details: VerifiableCredentials.authorization_details(user),
           credential_configuration: VerifiableCredentials.credential_configuration(user),
           presentation_configuration: VerifiablePresentations.presentation_configuration(user)
         }}

      _ ->
        {:error, "Invalid username or password."}
    end
  end

  def get_by(_), do: {:error, "Invalid username or password."}

  @impl Boruta.Oauth.ResourceOwners
  def check_password(%ResourceOwner{extra_claims: extra_claims}, password) do
    backend = Backend.default!()

    case apply(
           Backend.implementation(backend),
           :check_user_against,
           [backend, extra_claims[:user], %{password: password}]
         ) do
      {:ok, _user} ->
        :ok

      _ ->
        {:error, "Invalid username or password."}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{sub: sub}) when not is_nil(sub) do
    Accounts.get_user_scopes(sub) ++
      Enum.flat_map(Accounts.get_user_roles(sub), fn %{scopes: scopes} -> scopes end)
  end

  def authorized_scopes(_), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(%ResourceOwner{sub: sub}, scope) do
    case Accounts.get_user(sub) do
      %User{} = user ->
        scope
        |> Scope.split()
        |> Enum.reduce(%{}, fn scope, acc -> merge_claims(scope, acc, user, sub) end)
        |> Map.put("scope", scope)

      _ ->
        %{}
    end
  end

  @spec metadata(user :: User.t(), scope :: String.t()) :: metadata :: map()
  def metadata(%User{username: username, metadata: %{} = metadata}, _scope) when metadata == %{}, do: %{
    "email" => username
  }

  def metadata(user, scope) do
    user.metadata
    |> User.metadata_filter(user.backend)
    |> metadata_scope_filter(scope, user.backend)
    |> Enum.into(%{})
    |> Map.put("email", user.username)
  end

  defp merge_claims(
    "email",
    acc,
    %User{
      username: username,
      confirmed_at: confirmed_at
    },
    _sub
  ) do
    Map.merge(acc, %{
      "email" => username,
      "email_verified" => !!confirmed_at
    })
  end

  defp merge_claims("profile", acc, _user, sub) do
    roles = Accounts.get_user_roles(sub)
    organizations = Accounts.get_user_organizations(sub)

    acc
    |> Map.put(
      "organizations",
      Enum.map(organizations, fn %Organization{} = organization ->
        Map.from_struct(organization)
        |> Map.take([:id, :name, :label])
        |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
        |> Enum.into(%{})
      end)
    )
    |> Map.put("roles", Enum.map(roles, fn %Role{name: name} -> name end))
  end

  defp merge_claims(_, acc, _user, _sub), do: acc

  defp metadata_scope_filter(metadata, request_scope, %Backend{metadata_fields: metadata_fields}) do
    Enum.filter(metadata, fn {key, _value} ->
      # does backend metadata fields configuration allows current field according to scope ?
      Enum.reduce(metadata_fields, true, fn
        %{"attribute_name" => ^key, "scopes" => scopes}, acc ->
          case scopes do
            nil ->
              acc && true

            scopes ->
              request_scopes = Scope.split(request_scope)
              Enum.empty?(scopes -- request_scopes)
          end

        _, acc ->
          acc && true
      end)
    end)
    |> Enum.into(%{})
  end

  @impl Boruta.Oauth.ResourceOwners
  def trust_chain(client) do
    case FederationEntities.get_federation_entity_by_client_id(client.id) do
      nil ->
        {:ok, []}
      entity ->
        TrustChains.generate_trust_chain(entity)
    end
  end
end
