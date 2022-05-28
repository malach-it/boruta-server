defmodule BorutaIdentity.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username) do
    case Accounts.get_user_by_email(username) do
      %User{id: id, username: email, last_login_at: last_login_at} ->
        {:ok, %ResourceOwner{sub: id, username: email, last_login_at: last_login_at}}
      _ -> {:error, "User not found."}
    end
  end
  def get_by(sub: sub) when not is_nil(sub) do
    case Accounts.get_user(sub) do
      %User{id: id, username: email, last_login_at: last_login_at} ->
        {:ok, %ResourceOwner{sub: id, username: email, last_login_at: last_login_at}}
      _ -> {:error, "User not found."}
    end
  end
  # TODO investigate nil values
  def get_by(_), do: {:error, "User not found."}

  @impl Boruta.Oauth.ResourceOwners
  def check_password(%ResourceOwner{username: username}, password) do
    with {:ok, user} <- Accounts.Internal.get_user(%{email: username}),
         true <- Internal.User.valid_password?(user, password) do
      :ok
    else
      _ -> {:error, "Invalid password."}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{sub: sub}) when not is_nil(sub) do
    scopes = Accounts.get_user_scopes(sub)

    Enum.map(scopes, fn (%{id: id, name: name}) -> %Scope{id: id, name: name} end)
  end
  # TODO investigate nil values
  def authorized_scopes(_), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(%ResourceOwner{sub: sub}, scope) do
    case Accounts.get_user(sub) do
      %User{username: email} ->
        scope
        |> Scope.split()
        |> Enum.reduce(%{}, fn
          "email", acc ->
            Map.merge(acc, %{
              "email" => email,
              "email_verified" => false
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

      _ ->
        %{}
    end
  end
end
