defmodule Boruta.Oauth.Request do
  @moduledoc """
  Build a business structs from given input.

  Note : Input must have the shape or be a `%Plug.Conn{}` request.
  """

  # TODO unit test

  alias Boruta.BasicAuth
  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectRequest
  alias Boruta.Oauth.PasswordRequest
  alias Boruta.Oauth.TokenRequest
  alias Boruta.Oauth.Validator

  @doc """
  Create business struct from an OAuth token request.

  ## Examples
      iex>token_request(%{
        body_params: %{
          "grant_type" => "client_credentials",
          "client_id" => "client_id",
          "client_secret" => "client_secret"
        }
      })
      {:ok, %ClientCredentialsRequest{...}}
  """
  @spec token_request(conn :: Plug.Conn.t() | map()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, oauth_request :: %AuthorizationCodeRequest{}
      | %ClientCredentialsRequest{}
      | %CodeRequest{}
      | %TokenRequest{}
      | %PasswordRequest{}}
  # Handle Plug.Conn to extract header authorization (could not implement that as a guard)
  def token_request(%Plug.Conn{req_headers: req_headers, body_params: %{} = body_params}) do
    with {"authorization", authorization_header} <- Enum.find(
      req_headers,
      fn (header) -> elem(header, 0) == "authorization" end
    ) do
      token_request(%{
        req_headers: [{"authorization", authorization_header}],
        body_params: %{} = body_params
      })
    else
      nil ->
        token_request(%{body_params: %{} = body_params})
    end
  end
  def token_request(%{req_headers: [{"authorization", authorization_header}], body_params: %{} = body_params}) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         {:ok, params} <- Validator.validate(
           Enum.into(body_params, %{"client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error}}
    end
  end
  def token_request(%{body_params: %{} = body_params}) do
    with {:ok, params} <- Validator.validate(body_params) do
      build_request(params)
    else
      {:error, error_description} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error_description}}
    end
  end
  def token_request(%{}) do
    {:error, %Error{status: :bad_request, error: :invalid_request, error_description: "Must provide body_params."}}
  end

  @doc """
  Create business struct from an OAuth authorize request.

  Note : resource owner must be provided as current_user assigns.

  ## Examples
      iex>authorize_request(%{
        query_params: %{
          "response_type" => "token",
          "client_id" => "client_id",
          "redirect_uri" => "redirect_uri"
        },
        assigns: %{current_user: %User{...}}
      })
      {:ok, %TokenRequest{...}}
  """
  @spec authorize_request(conn :: map()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, oauth_request :: %AuthorizationCodeRequest{}
      | %ClientCredentialsRequest{}
      | %CodeRequest{}
      | %TokenRequest{}
      | %PasswordRequest{}}
  def authorize_request(%{query_params: query_params, assigns: assigns}) do
    with {:ok, params} <- Validator.validate(query_params) do
      build_request(Enum.into(params, %{"resource_owner" => assigns[:current_user]}))
    else
      {:error, error_description} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error_description}}
    end
  end
  def authorize_request(%{}) do
    {:error, %Error{status: :bad_request, error: :invalid_request, error_description: "Must provide query_params and assigns."}}
  end

  @doc """
  Create business struct from an OAuth introspect request.

  ## Examples
      iex>introspect_request(%{
        body_params: %{
          "token" => "token",
          "client_id" => "client_id",
          "client_secret" => "client_secret",
        }
      })
      {:ok, %IntrospectRequest{...}}
  """
  @spec introspect_request(conn :: Plug.Conn.t() | map()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, introspect_request :: %IntrospectRequest{}}
  # Handle Plug.Conn to extract header authorization (could not implement that as a guard)
  def introspect_request(%Plug.Conn{req_headers: req_headers, body_params: %{} = body_params}) do
    with {"authorization", authorization_header} <- Enum.find(
      req_headers,
      fn (header) -> elem(header, 0) == "authorization" end
    ) do
      introspect_request(%{
        req_headers: [{"authorization", authorization_header}],
        body_params: %{} = body_params
      })
    else
      nil ->
        introspect_request(%{body_params: %{} = body_params})
    end
  end
  def introspect_request(%{req_headers: [{"authorization", authorization_header}], body_params: %{} = body_params}) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         {:ok, params} <- Validator.validate(
           Enum.into(body_params, %{"response_type" => "introspect", "client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error}}
    end
  end
  def introspect_request(%{body_params: %{} = body_params}) do
    with {:ok, params} <- Validator.validate(Enum.into(body_params, %{"response_type" => "introspect"})) do
      build_request(params)
    else
      {:error, error_description} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error_description}}
    end
  end
  def introspect_request(%{}) do
    {:error, %Error{status: :bad_request, error: :invalid_request, error_description: "Must provide body_params."}}
  end

  # private
  defp build_request(%{"grant_type" => "client_credentials"} = params) do
    {:ok, struct(ClientCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      scope: params["scope"]
    })}
  end
  defp build_request(%{"grant_type" => "password"} = params) do
    {:ok, struct(PasswordRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      username: params["username"],
      password: params["password"],
      scope: params["scope"]
    })}
  end
  defp build_request(%{"grant_type" => "authorization_code"} = params) do
    {:ok, struct(AuthorizationCodeRequest, %{
      client_id: params["client_id"],
      code: params["code"],
      redirect_uri: params["redirect_uri"]
    })}
  end

  defp build_request(%{"response_type" => "token"} = params) do
    {:ok, struct(TokenRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      resource_owner: params["resource_owner"],
      state: params["state"],
      scope: params["scope"]
    })}
  end
  defp build_request(%{"response_type" => "code"} = params) do
    {:ok, struct(CodeRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      resource_owner: params["resource_owner"],
      state: params["state"],
      scope: params["scope"]
    })}
  end
  defp build_request(%{"response_type" => "introspect"} = params) do
    {:ok, struct(IntrospectRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      token: params["token"]
    })}
  end
end
