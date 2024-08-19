defmodule BorutaWeb.Router do
  use BorutaWeb, :router
  use Plug.ErrorHandler

  import BorutaIdentityWeb.Sessions,
    only: [
      fetch_current_user: 2
    ]

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :protected do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json", "jwt"])
  end

  scope "/", BorutaWeb do
    pipe_through(:api)

    get("/.well-known/openid-configuration", OpenidController, :well_known)
    get("/.well-known/openid-credential-issuer", OpenidController, :openid_credential_issuer)
  end

  get("/healthcheck", BorutaWeb.MonitoringController, :healthcheck, log: false)

  forward("/accounts", BorutaIdentityWeb.Endpoint)

  scope "/openid", BorutaWeb do
    pipe_through(:api)

    post("/credential", Openid.CredentialController, :credential)
    post("/defered-credential", Openid.CredentialController, :defered_credential)
    get("/jwks", Openid.JwksController, :jwks_index)
    get("/jwks/:client_id", Openid.JwksController, :jwks_show)

    post("/register", Openid.DynamicRegistrationController, :register_client)
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through(:api)

    post("/token", TokenController, :token)
    post("/introspect", IntrospectController, :introspect)
    post("/pushed_authorization_request", PushedAuthorizationRequestController, :pushed_authorization_request)
    post("/revoke", RevokeController, :revoke)
    options("/introspect", IntrospectController, :options)
    options("/revoke", RevokeController, :options)
  end

  scope "/oauth", BorutaWeb do
    pipe_through(:api)

    get("/userinfo", Openid.UserinfoController, :userinfo)
    post("/userinfo", Openid.UserinfoController, :userinfo)
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through([:browser, :fetch_current_user])

    get("/authorize", AuthorizeController, :authorize)
  end

  scope "/did", BorutaWeb do
    pipe_through([:api])

    get("/resolve_status/:status", DidController, :resolve_status)
  end

  scope "/openid", BorutaWeb.Oauth do
    pipe_through([:api])

    post("/direct_post/:code_id", TokenController, :direct_post)
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, error) do
    BorutaIdentityWeb.Router.handle_errors(conn, error)
  end
end
