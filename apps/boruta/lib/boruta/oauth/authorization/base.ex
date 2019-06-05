defmodule Boruta.Oauth.Authorization.Base do
  @moduledoc """
  TODO Base artifacts authorization
  """

  import Ecto.Query, only: [from: 2]

  alias Boruta.Coherence.User
  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def client(id: id, secret: secret) do
    with %Client{} = client <- Repo.get_by(Client, id: id, secret: secret) do
      {:ok, client}
    else
      nil ->
        {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or client_secret."}}
    end
  end

  def client(id: id, redirect_uri: redirect_uri) do
    with %Client{} = client <- Repo.get_by(Client, id: id, redirect_uri: redirect_uri) do
      {:ok, client}
    else
      nil ->
        {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or redirect_uri."}}
    end
  end

  def resource_owner(id: id) do
    with %User{} = resource_owner <- Repo.get_by(User, id: id) do
      {:ok, resource_owner}
    else
      _ ->
        {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}
    end
  end
  # TODO return more explicit error (that should be rescued in controller and not be sent to the client)
  def resource_owner(email: username, password: password) do
    with %User{} = resource_owner <- Repo.get_by(User, email: username),
         true <- User.checkpw(password, resource_owner.password_hash) do
      {:ok, resource_owner}
    else
      _ ->
        {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}
    end
  end
  def resource_owner(%User{__meta__: %{state: :loaded}} = resource_owner), do: {:ok, resource_owner}
  # TODO return more explicit error (that should be rescued in controller and not be sent to the client)
  def resource_owner(_), do: {:unauthorized, %{error: "invalid_resource_owner", error_description: "Resource owner is invalid."}}

  def code(value: value, redirect_uri: redirect_uri) do
    with %Token{} = token <- Repo.get_by(Token, type: "code", value: value, redirect_uri: redirect_uri),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:unauthorized, %{error: "invalid_code", error_description: error}}
      nil ->
        {:unauthorized, %{error: "invalid_code", error_description: "Provided authorization code is incorrect."}}
    end
  end

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
        {:unauthorized, %{error: "invalid_access_token", error_description: error}}
      nil ->
        {:unauthorized, %{error: "invalid_access_token", error_description: "Provided authorization code is incorrect."}}
    end
  end

  def scope(scope: scope, client: %Client{authorize_scope: false}), do: {:ok, scope}
  def scope(scope: scope, client: %Client{authorize_scope: true, authorized_scopes: authorized_scopes}) do
    scopes = String.split(scope, " ")
    case Enum.empty?(scopes -- authorized_scopes) do # if all scopes are authorized
      true -> {:ok, scope}
      false ->
        {:bad_request, %{error: "invalid_scope", error_description: "Given scopes are not authorized."}}
    end
  end
end
