defmodule BorutaIdentity.Accounts.Users do
  @moduledoc false

  import Ecto.Query

  alias Boruta.Ecto.Scopes
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @spec get_user_by_email(backend :: Backend.t(), email :: String.t()) :: user :: User.t() | nil
  def get_user_by_email(backend, email) when is_binary(email) do
    # TODO remove backend_user from domain
    case apply(
           Backend.implementation(backend),
           :get_user,
           [backend, %{email: email}]
         ) do
      {:ok, backend_user} ->
        apply(
          Backend.implementation(backend),
          :domain_user!,
          [backend_user, backend]
        )

      _ ->
        nil
    end
  end

  @spec get_user(id :: String.t()) :: user :: User.t() | nil
  def get_user(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        left_join: b in assoc(u, :backend),
        preload: [authorized_scopes: as, backend: b],
        where: u.id == ^id
      )
    )
  end

  @doc """
  Gets the user with the given signed token.
  """
  @spec get_user_by_session_token(token :: String.t()) :: user :: User.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query) |> Repo.preload(:backend)
  end

  @spec get_user_scopes(user_id :: String.t()) :: user :: list(UserAuthorizedScope.t()) | nil
  def get_user_scopes(user_id) do
    scopes = Scopes.all()

    Repo.all(from(u in UserAuthorizedScope, where: u.user_id == ^user_id))
    |> Enum.map(fn user_scope ->
      Enum.find(scopes, fn %{id: id} -> id == user_scope.scope_id end)
    end)
    |> Enum.flat_map(fn
      %{id: id, name: name} -> [%Scope{id: id, name: name}]
      _ -> []
    end)
  end
end
