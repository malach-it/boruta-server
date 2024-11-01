defmodule BorutaAdminWeb.Authorization do
  @moduledoc false
  @dialyzer {:no_unused, {:maybe_validate_user, 1}}

  @behaviour Boruta.Openid.UserinfoApplication

  require Logger

  alias Boruta.Oauth.Authorization.ResourceOwner
  use BorutaAdminWeb, :controller

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid.UserinfoResponse
  alias BorutaAdminWeb.ErrorView
  alias BorutaWeb.ResourceOwners

  def require_authenticated(conn, _opts \\ []) do
    with [authorization_header] <- get_req_header(conn, "authorization"),
         [_authorization_header, access_token] <-
           Regex.run(~r/Bearer (.+)/, authorization_header),
         {:ok, token} <- Boruta.Oauth.Authorization.AccessToken.authorize(value: access_token) do
      userinfo = ResourceOwners.claims(%ResourceOwner{sub: token.sub}, "profile")

      case maybe_validate_user(userinfo) do
        :ok ->
          conn
          |> assign(:authorization, %{
            "scope" => token.scope,
            "sub" => token.sub
          })

        error ->
          respond_unauthorized(conn, error)
      end
    else
      {:error, _error} ->
        with [authorization_header] <- get_req_header(conn, "authorization"),
             [_authorization_header, access_token] <-
               Regex.run(~r/Bearer (.+)/, authorization_header),
             {:ok, userinfo} <- userinfo(access_token),
             :ok <- maybe_validate_user(userinfo) do
          assign(conn, :authorization, userinfo)
        else
          e ->
            respond_unauthorized(conn, e)
        end

      e ->
        respond_unauthorized(conn, e)
    end
  end

  @impl Boruta.Openid.UserinfoApplication
  def unauthorized(_conn, error) do
    {:error, error}
  end

  @impl Boruta.Openid.UserinfoApplication
  def userinfo_fetched(_conn, userinfo_response) do
    userinfo =
      UserinfoResponse.payload(%{userinfo_response | format: :json})
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    {:ok, userinfo}
  end

  def authorize(conn, [_h | _t] = scopes) do
    current_scopes = String.split(conn.assigns[:authorization]["scope"], " ")

    case Enum.empty?(scopes -- current_scopes) do
      true ->
        conn

      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
        |> halt()
    end
  end

  def authorize(conn, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render("403.json")
    |> halt()
  end

  # TODO cache token introspection
  def userinfo(access_token) do
    site = Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:oauth2][:site]

    with {:ok, %Finch.Response{body: body}} <-
           Finch.build(
             :get,
             "#{site}/oauth/userinfo",
             [
               {"accept", "application/json"},
               {"authorization", "Bearer " <> access_token}
             ]
           )
           |> Finch.request(FinchHttp) do
      Jason.decode(body)
    end
  end

  defp respond_unauthorized(conn, e) do
    Logger.debug("User unauthorized : #{inspect(e)}")

    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render("401.json")
    |> halt()
  end

  defp maybe_validate_user(userinfo) do
    case {
      Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:sub_restricted],
      Application.get_env(:boruta_web, BorutaAdminWeb.Authorization)[:organization_restricted]
    } do
      {_, "" <> restricted_organization} ->
        case Map.get(userinfo, "organizations", [])
             |> Enum.map(fn %{"id" => id} -> id end)
             |> Enum.member?(restricted_organization) do
          true ->
            :ok

          false ->
            {:error, "Instance management is restricted to #{restricted_organization}"}
        end

      {"" <> restricted_sub, _} ->
        case userinfo["sub"] do
          ^restricted_sub ->
            :ok

          _ ->
            {:error, "Instance management is restricted to #{restricted_sub}"}
        end

      {_, _} ->
        :ok
    end
  end
end
