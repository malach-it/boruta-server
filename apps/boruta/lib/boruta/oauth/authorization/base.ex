defmodule Boruta.Oauth.Authorization.Base do
  @moduledoc """
  Base artifacts authorization
  """

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [user_checkpw_method: 0, resource_owner_schema: 0, repo: 0]

  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token

  @doc """
  Authorize the client corresponding to the given params.

  ## Examples
      iex> client(id: "id", secret: "secret")
      {:ok, %Boruta.Oauth.Client{...}}
  """
  @spec client([id: String.t(), secret: String.t()] | [id: String.t(), redirect_uri: String.t()]) ::
    {:ok, %Boruta.Oauth.Client{}}
    | {:error,
      %Boruta.Oauth.Error{
        :error => :invalid_client,
        :error_description => String.t(),
        :format => nil,
        :redirect_uri => nil,
        :status => :unauthorized
      }}
  def client(id: id, secret: secret) do
    with %Client{} = client <- repo().get_by(Client, id: id, secret: secret) do
      {:ok, client}
    else
      nil ->
        {:error, %Error{status: :unauthorized, error: :invalid_client, error_description: "Invalid client_id or client_secret."}}
    end
  end
  def client(id: id, redirect_uri: redirect_uri) do
    with %Client{} = client <- repo().get_by(Client, id: id, redirect_uri: redirect_uri) do
      {:ok, client}
    else
      nil ->
        {:error, %Error{status: :unauthorized, error: :invalid_client, error_description: "Invalid client_id or redirect_uri."}}
    end
  end

  @doc """
  Authorize the resource owner corresponding to the given params.

  ## Examples
      iex> resource_owner(id: "id")
      {:ok, %User{...}}
  """
  @spec resource_owner([id: String.t()] | [email: String.t(), password: String.t()] | struct()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_resource_owner,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, user :: struct()}
  def resource_owner(id: id) do
    # if resource_owner is a struct
    with %{__struct__: _} = resource_owner <- repo().get_by(resource_owner_schema(), id: id) do
      {:ok, resource_owner}
    else
      _ ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "User not found."
        }}
    end
  end
  def resource_owner(email: username, password: password) do
    # if resource_owner is a struct
    with %{__struct__: _} = resource_owner <- repo().get_by(resource_owner_schema(), email: username),
         true <- apply(user_checkpw_method(), [password, resource_owner.password_hash]) do
      {:ok, resource_owner}
    else
      _ ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "Invalid username or password."
        }}
    end
  end
  def resource_owner(%{__meta__: %{state: :loaded}} = resource_owner) do # resource_owner is persisted
    {:ok, resource_owner}
  end
  def resource_owner(_) do
    {:error, %Error{
      status: :unauthorized,
      error: :invalid_resource_owner,
      error_description: "Resource owner is invalid.",
      format: :internal
    }}
  end

  @doc """
  Authorize the code corresponding to the given params.

  ## Examples
      iex> code(value: "value", redirect_uri: "redirect_uri")
      {:ok, %Boruta.Oauth.Token{...}}
  """
  @spec code([value: String.t(), redirect_uri: String.t()]) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_code,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, %Boruta.Oauth.Token{}}
  def code(value: value, redirect_uri: redirect_uri) do
    with %Token{} = token <- repo().get_by(Token, type: "code", value: value, redirect_uri: redirect_uri),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_code, error_description: error}}
      nil ->
        {:error, %Error{status: :bad_request, error: :invalid_code, error_description: "Provided authorization code is incorrect."}}
    end
  end

  @doc """
  Authorize the access token corresponding to the given params.

  ## Examples
      iex> access_token(value: "value")
      {:ok, %Boruta.Oauth.Token{...}}
  """
  @spec access_token([value: String.t()] | [refresh_token: String.t()]) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_access_token,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, %Boruta.Oauth.Token{}}
  def access_token(value: value) do
    with %Token{} = token <- repo().one(
      from t in Token,
      left_join: c in assoc(t, :client),
      left_join: u in assoc(t, :resource_owner),
      where: t.type == "access_token" and t.value == ^value,
      preload: [client: c, resource_owner: u]
    ),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_access_token, error_description: error}}
      nil ->
        {:error, %Error{status: :bad_request, error: :invalid_access_token, error_description: "Provided access token is incorrect."}}
    end
  end
  def access_token(refresh_token: refresh_token) do
    with %Token{} = token <- repo().one(
      from t in Token,
      left_join: c in assoc(t, :client),
      left_join: u in assoc(t, :resource_owner),
      where: t.type == "access_token" and t.refresh_token == ^refresh_token,
      preload: [client: c, resource_owner: u]
    ),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_refresh_token, error_description: error}}
      nil ->
        {:error, %Error{status: :bad_request, error: :invalid_refresh_token, error_description: "Provided refresh token is incorrect."}}
    end
  end

  @doc """
  Authorize the given scope according to the given client.

  ## Examples
      iex> scope(scope: "scope", client: %Boruta.Oauth.Client{...})
      {:ok, "scope"}
  """
  @spec scope([scope: String.t(), client: Client.t()] | [scope: String.t(), token: Token.t()]) ::
    {:ok, scope :: String.t()} | {:error, Error.t()}
  def scope(scope: nil, client: _), do: {:ok, nil}
  def scope(scope: "" <> scope, client: %Client{authorize_scope: false}) do
    scopes = Scope.split(scope)

    private_scopes = repo().all(from s in Scope, select: s.name, where: s.public == false)
    case Enum.any?(scopes, fn (scope) -> scope in private_scopes end) do # if all scopes are authorized
      false -> {:ok, scope}
      true ->
        {:error, %Error{status: :bad_request, error: :invalid_scope, error_description: "Given scopes are not authorized."}}
    end
  end
  def scope(scope: "" <> scope, client: %Client{authorize_scope: true} = client) do
    scopes = Enum.filter(String.split(scope, " "), fn (scope) -> scope != "" end) # remove empty strings

    client = repo().preload(client, :authorized_scopes)
    authorized_scopes = Enum.map(client.authorized_scopes, fn (e) -> e.name end)

    case Enum.empty?(scopes -- authorized_scopes) do # if all scopes are authorized
      true -> {:ok, scope}
      false ->
        {:error, %Error{status: :bad_request, error: :invalid_scope, error_description: "Given scopes are not authorized."}}
    end
  end

  # TODO default token scope may be an empty string
  def scope(scope: nil, token: _), do: {:ok, nil}
  def scope(scope: "", token: %Token{scope: nil}), do: {:ok, ""}
  def scope(scope: "" <> _, token: %Token{scope: nil}) do
    {:error, %Error{status: :bad_request, error: :invalid_scope, error_description: "Given scopes are not authorized."}}
  end
  def scope(scope: scope, token: %Token{scope: "" <> authorized_scope}) do
    authorized_scopes = Scope.split(authorized_scope)
    scopes = Scope.split(scope)
    case Enum.empty?(scopes -- authorized_scopes) do # if all scopes are authorized
      true -> {:ok, scope}
      false ->
        {:error, %Error{status: :bad_request, error: :invalid_scope, error_description: "Given scopes are not authorized."}}
    end
  end
end
