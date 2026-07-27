defmodule BorutaWeb.Openid.UserinfoController do
  @behaviour Boruta.Openid.UserinfoApplication

  use BorutaWeb, :controller

  alias Boruta.Openid
  alias Boruta.Openid.UserinfoResponse
  alias Boruta.Oauth.Authorization.AccessToken
  alias Boruta.Oauth.BearerToken
  alias Boruta.Oauth.Error
  alias BorutaIdentity.PhiAccessProof
  alias BorutaWeb.OpenidView

  def userinfo(conn, _params) do
    Openid.userinfo(conn, __MODULE__)
  end

  @impl Boruta.Openid.UserinfoApplication
  def userinfo_fetched(conn, response) do
    with {:ok, access_token} <- BearerToken.extract_token(conn),
         {:ok, token} <- AccessToken.authorize(value: access_token),
         {:ok, userinfo} <- PhiAccessProof.add(response.userinfo, token) do
      response = UserinfoResponse.from_userinfo(userinfo, token.client)

      conn
      |> put_view(OpenidView)
      |> put_resp_header("content-type", UserinfoResponse.content_type(response))
      |> render("userinfo.#{response.format}", response: response)
    else
      {:error, %Error{} = error} ->
        unauthorized(conn, error)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "phi_access_proof_error", error_description: inspect(reason)})
    end
  end

  @impl Boruta.Openid.UserinfoApplication
  def unauthorized(conn, error) do
    conn
    |> put_resp_header(
      "www-authenticate",
      "error=\"#{error.error}\", error_description=\"#{error.error_description}\""
    )
    |> send_resp(:unauthorized, "")
  end
end
