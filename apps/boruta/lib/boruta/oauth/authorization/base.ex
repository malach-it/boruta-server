defmodule Boruta.Oauth.Authorization.Base do
  @moduledoc """
  Base artifacts authorization
  """

  import Ecto.Query, only: [from: 2]

  alias Boruta.Coherence.User
  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token
  alias Boruta.Repo

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
    with %Client{} = client <- Repo.get_by(Client, id: id, secret: secret) do
      {:ok, client}
    else
      nil ->
        {:error, %Error{status: :unauthorized, error: :invalid_client, error_description: "Invalid client_id or client_secret."}}
    end
  end
  def client(id: id, redirect_uri: redirect_uri) do
    with %Client{} = client <- Repo.get_by(Client, id: id, redirect_uri: redirect_uri) do
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
  @spec resource_owner([id: String.t()] | [email: String.t(), password: String.t()] | User.t()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_resource_owner,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, %Boruta.Coherence.User{}}
  def resource_owner(id: id) do
    with %User{} = resource_owner <- Repo.get_by(User, id: id) do
      {:ok, resource_owner}
    else
      _ ->
        {:error, %Error{status: :unauthorized, error: :invalid_resource_owner, error_description: "Invalid username or password."}}
    end
  end
  # TODO return more explicit error (that should be rescued in controller and not be sent to the client)
  def resource_owner(email: username, password: password) do
    with %User{} = resource_owner <- Repo.get_by(User, email: username),
         true <- User.checkpw(password, resource_owner.password_hash) do
      {:ok, resource_owner}
    else
      _ ->
        {:error, %Error{status: :unauthorized, error: :invalid_resource_owner, error_description: "Invalid username or password."}}
    end
  end
  def resource_owner(%User{__meta__: %{state: :loaded}} = resource_owner), do: {:ok, resource_owner}
  # TODO return more explicit error (that should be rescued in controller and not be sent to the client)
  def resource_owner(_), do: {:error, %Error{status: :unauthorized, error: :invalid_resource_owner, error_description: "Resource owner is invalid."}}

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
       :status => :unauthorized
     }}
    | {:ok, %Boruta.Oauth.Token{}}
  def code(value: value, redirect_uri: redirect_uri) do
    with %Token{} = token <- Repo.get_by(Token, type: "code", value: value, redirect_uri: redirect_uri),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error, %Error{status: :unauthorized, error: :invalid_code, error_description: error}}
      nil ->
        {:error, %Error{status: :unauthorized, error: :invalid_code, error_description: "Provided authorization code is incorrect."}}
    end
  end

  @doc """
  Authorize the access token corresponding to the given params.

  ## Examples
      iex> access_token(value: "value")
      {:ok, %Boruta.Oauth.Token{...}}
  """
  @spec access_token([value: String.t()]) ::
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
    with %Token{} = token <- Repo.one(
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
        {:error, %Error{status: :unauthorized, error: :invalid_access_token, error_description: error}}
      nil ->
            {:error, %Error{status: :unauthorized, error: :invalid_access_token, error_description: "Provided authorization code is incorrect."}}
    end
  end

  @doc """
  Authorize the given scope according to the given client.

  ## Examples
      iex> scope(scope: "scope", client: %Boruta.Oauth.Client{...})
      {:ok, "scope"}
  """
  @spec scope([scope: String.t(), client: Client.t()]) ::
    {:ok, scope :: String.t()} | {:error, Error.t()}
  def scope(scope: scope, client: %Client{authorize_scope: false}), do: {:ok, scope}
  def scope(scope: scope, client: %Client{authorize_scope: true, authorized_scopes: authorized_scopes}) do
    scopes = String.split(scope, " ")
    case Enum.empty?(scopes -- authorized_scopes) do # if all scopes are authorized
      true -> {:ok, scope}
      false ->
        {:error, %Error{status: :bad_request, error: :invalid_scope, error_description: "Given scopes are not authorized."}}
    end
  end
end
