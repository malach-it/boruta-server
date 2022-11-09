defmodule BorutaIdentity.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  use BorutaIdentityWeb, :controller

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend

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
         extra_claims: %{user: impl_user}
       }}
    else
      _ ->
        {:error, "Invalid username or password."}
    end
  end

  def get_by(sub: sub) when not is_nil(sub) do
    case Accounts.get_user(sub) do
      %User{id: id, username: email, last_login_at: last_login_at} ->
        {:ok, %ResourceOwner{sub: id, username: email, last_login_at: last_login_at}}

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
    Accounts.get_user_scopes(sub)
  end

  def authorized_scopes(_), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(%ResourceOwner{sub: sub}, scope) do
    case Accounts.get_user(sub) do
      %User{username: email, confirmed_at: confirmed_at, metadata: metadata} ->
        scope
        |> Scope.split()
        |> Enum.reduce(%{}, fn
          "email", acc ->
            Map.merge(acc, %{
              "email" => email,
              "email_verified" => !!confirmed_at
            })

          "phone", acc ->
            Map.merge(acc, %{
              "phone_number_verified" => false,
              "phone_number" => "+33612345678"
            })

          "profile", acc ->
            Map.merge(acc, %{
              "profile" => "http://profile.host",
              "preferred_username" => "prefered_username",
              "updated_at" => :os.system_time(:seconds),
              "website" => "website",
              "zoneinfo" => "zoneinfo",
              "birthdate" => "2021-08-01",
              "gender" => "gender",
              "prefered_username" => "prefered_username",
              "given_name" => "given_name",
              "middle_name" => "middle_name",
              "locale" => "FR",
              "picture" => "picture",
              "updates_at" => "updates_at",
              "name" => "name",
              "nickname" => "nickname",
              "family_name" => "family_name"
            })

          "address", acc ->
            Map.put(acc, "address", %{
              "formatted" => "3 rue Dupont-Moriety, 75021 Paris, France",
              "street_address" => "3 rue Dupont-Moriety",
              "locality" => "Paris",
              "region" => "Ile-de-France",
              "postal_code" => "75021",
              "country" => "France"
            })

          _, acc ->
            acc
        end)
        |> Map.merge(metadata)

      _ ->
        %{}
    end
  end
end
