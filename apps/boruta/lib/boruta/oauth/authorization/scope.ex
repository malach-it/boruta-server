defmodule Boruta.Oauth.Authorization.Scope do
  @moduledoc false

  alias Boruta.Accounts.User
  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]

  @type params :: [
    scope: String.t(),
    against: %{
      optional(:client) => %Client{},
      optional(:resource_owner) => %User{},
      optional(:token) => %Token{},
    }
  ]

  @doc """
  Authorize the given scope according to the given client.

  ## Examples
      iex> authorize(%{scope: "scope", client: %Client{...}})
      {:ok, "scope"}
  """
  @spec authorize(params :: params) ::
    {:ok, scope :: String.t()} | {:error, Error.t()}
  def authorize(scope: nil, against: %{client: _, resource_owner: _, token: _}), do: {:ok, ""}
  def authorize(scope: "", against: %{client: _, resource_owner: _, token: _}), do: {:ok, ""}
  def authorize(scope: "" <> scope, against: %{client: client, resource_owner: resource_owner, token: nil}) do
    scopes = Scope.split(scope)

    public_scopes = scopes |> keep_if_authorized(:public)
    resource_owner_scopes = scopes |> keep_if_authorized(resource_owner)
    client_scopes = scopes |> keep_if_authorized(client)
    authorized_scopes = Enum.uniq(public_scopes ++ resource_owner_scopes ++ client_scopes)

    authorized?(scopes, authorized_scopes)
  end
  def authorize(scope: "" <> scope, against: %{client: _, resource_owner: _, token: token}) do
    scopes = Scope.split(scope)

    authorized_scopes = scopes |> keep_if_authorized(token)

    authorized?(scopes, authorized_scopes)
  end
  def authorize(scope: scope, against: %{} = against) do
    authorize(
      scope: scope,
      against: %{
        client: against[:client],
        resource_owner: against[:resource_owner],
        token: against[:token]
      })
  end

  defp keep_if_authorized(_scopes, nil), do: []
  defp keep_if_authorized(scopes, :public) do
    authorized_scopes = repo().all(
      from s in Scope,
      where: s.public == true
    )
    |> Enum.map(fn (scope) -> scope.name end)

    Enum.filter(scopes, fn (scope) ->
      Enum.member?(authorized_scopes, scope)
    end)
  end
  defp keep_if_authorized(scopes, %Client{authorize_scope: false}) do
    keep_if_authorized(scopes, :public)
  end
  defp keep_if_authorized(scopes, %Client{authorize_scope: true} = client) do
    client = repo().preload(client, :authorized_scopes)
    authorized_scopes = Enum.map(client.authorized_scopes, fn (e) -> e.name end)

    Enum.filter(scopes, fn (scope) ->
      Enum.member?(authorized_scopes, scope)
    end)
  end
  defp keep_if_authorized(scopes, %User{} = resource_owner) do
    resource_owner = repo().preload(resource_owner, :authorized_scopes)
    authorized_scopes = Enum.map(resource_owner.authorized_scopes, fn (e) -> e.name end)

    Enum.filter(scopes, fn (scope) ->
      Enum.member?(authorized_scopes, scope)
    end)
  end
  defp keep_if_authorized(scopes, %Token{scope: "" <> authorized_scope}) do
    authorized_scopes = Scope.split(authorized_scope)

    Enum.filter(scopes, fn (scope) ->
      Enum.member?(authorized_scopes, scope)
    end)
  end
  defp keep_if_authorized(_scopes, _), do: []

  defp authorized?(scopes, authorized_scopes) do
    case Enum.empty?(scopes -- authorized_scopes) do
      true ->
        authorized_scope = Enum.join(authorized_scopes, " ")
        {:ok, authorized_scope}
      false ->
        {:error,  %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are unknown or unauthorized.",
          status: :bad_request
        }}
    end
  end
end
