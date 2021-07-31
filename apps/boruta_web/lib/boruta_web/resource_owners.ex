defmodule BorutaWeb.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username) do
    case Accounts.get_user_by_email(username) do
      %User{id: id, email: email} ->
        {:ok, %ResourceOwner{sub: id, username: email}}
      _ -> {:error, "User not found."}
    end
  end
  def get_by(sub: sub) do
    case Accounts.get_user(sub) do
      %User{id: id, email: email} ->
        {:ok, %ResourceOwner{sub: id, username: email}}
      nil -> {:error, "User not found."}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def check_password(%ResourceOwner{sub: sub}, password) do
    user = Accounts.get_user(sub)
    Accounts.check_user_password(user, password)
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{sub: sub}) do
    scopes = Accounts.get_user_scopes(sub)

    Enum.map(scopes, fn (%{id: id, name: name}) -> %Scope{id: id, name: name} end)
  end

  @impl Boruta.Oauth.ResourceOwners
  def claims(sub, scope) do
    with %User{email: email} <- Accounts.get_user(sub) do
      scope
      |> Scope.split()
      |> Enum.reduce(%{}, fn
        "email", acc -> Map.merge(acc, %{
            "email" => email,
            "email_verified" => false
        })
        "phone", acc -> Map.merge(acc, %{
          "phone_number_verified" => false,
          "phone_number" => "+33612345678"
        })
        "profile", acc -> Map.merge(acc, %{
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
            "family_name" => "family_name",
        })
        "address", acc -> Map.put(acc, "address", %{
          "formatted" => "3 rue Dupont-Moriety, 75021 Paris, France",
          "street_address" => "3 rue Dupont-Moriety",
          "locality" => "Paris",
          "region" => "Ile-de-France",
          "postal_code" => "75021",
          "country" => "France"
        })
        _, acc -> acc
      end)
    end
  end
end
