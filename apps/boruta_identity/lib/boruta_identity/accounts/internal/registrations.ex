defmodule BorutaIdentity.Accounts.Internal.Registrations do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  def register(user_params) do
    %User{}
    |> User.registration_changeset(user_params)
    |> Repo.insert()
  end
end
