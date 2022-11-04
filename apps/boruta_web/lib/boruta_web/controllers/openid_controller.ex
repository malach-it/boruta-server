defmodule BorutaWeb.OpenidController do
  @behaviour Boruta.Openid.Application

  use BorutaWeb, :controller

  alias Boruta.Oauth
  alias Boruta.Openid
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaWeb.OauthView
  alias BorutaWeb.OpenidView

  def userinfo(conn, _params) do
    Openid.userinfo(conn, __MODULE__)
  end

  @impl Boruta.Openid.Application
  def userinfo_fetched(conn, userinfo) do
    conn
    |> put_view(OauthView)
    |> render("userinfo.json", userinfo: userinfo)
  end

  @impl Boruta.Openid.Application
  def unauthorized(conn, error) do
    conn
    |> put_resp_header(
      "www-authenticate",
      "error=\"#{error.error}\", error_description=\"#{error.error_description}\""
    )
    |> send_resp(:unauthorized, "")
  end

  def jwks_index(conn, _params) do
    Openid.jwks(conn, __MODULE__)
  end

  @impl Boruta.Openid.Application
  def jwk_list(conn, jwk_keys) do
    conn
    |> put_view(OauthView)
    |> render("jwks.json", keys: jwk_keys)
  end

  def register_client(conn, params) do
    registration_params = %{
      redirect_uris: params["redirect_uris"]
    }

    Openid.register_client(conn, registration_params, __MODULE__)
  end

  @impl Boruta.Openid.Application
  def client_registered(conn, %Oauth.Client{id: client_id} = client) do
    with %Backend{id: backend_id} <- Backend.default!(),
         {:ok, %IdentityProvider{id: identity_provider_id}} <-
           IdentityProviders.create_identity_provider(%{name: "Created with dynamic registration for client #{client_id}", backend_id: backend_id}),
         {:ok, _client_identity_provider} <-
           IdentityProviders.upsert_client_identity_provider(client_id, identity_provider_id) do
      conn
      |> put_view(OpenidView)
      |> put_status(:created)
      |> render("client.json", client: client)
    else
      {:error, changeset} ->
        registration_failure(conn, changeset)
    end
  end

  @impl Boruta.Openid.Application
  def registration_failure(conn, changeset) do
    conn
    |> put_view(OpenidView)
    |> put_status(:bad_request)
    |> render("registration_error.json", changeset: changeset)
  end

  def well_known(conn, _params) do
    conn
    |> put_view(OauthView)
    |> render("well_known.json", routes: Routes)
  end
end
