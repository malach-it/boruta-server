defmodule BorutaWeb.Router do
  use BorutaWeb, :router
  use Plug.ErrorHandler

  import BorutaIdentityWeb.Sessions,
    only: [
      fetch_current_user: 2
    ]

  import BorutaWeb.Authorization,
    only: [
      require_authenticated: 2
    ]

  pipeline :protected_api do
    plug(:accepts, ["json"])

    plug(:require_authenticated)
  end

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
    plug(CORSPlug)

    plug(:accepts, ["json", "jwt"])
  end

  scope "/", BorutaWeb do
    pipe_through(:api)

    get("/.well-known/openid-configuration", OpenidController, :well_known)
  end

  get("/healthcheck", BorutaWeb.MonitoringController, :healthcheck, log: false)

  forward("/accounts", BorutaIdentityWeb.Endpoint)

  scope "/openid", BorutaWeb do
    pipe_through(:api)

    get("/jwks", OpenidController, :jwks_index)
    get("/jwks/:client_id", OpenidController, :jwks_show)
    post("/register", OpenidController, :register_client)
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through(:api)

    post("/token", TokenController, :token)
    post("/introspect", IntrospectController, :introspect)
    post("/revoke", RevokeController, :revoke)
    options("/introspect", IntrospectController, :options)
    options("/revoke", RevokeController, :options)
  end

  scope "/oauth", BorutaWeb do
    pipe_through(:api)

    get("/userinfo", OpenidController, :userinfo)
    post("/userinfo", OpenidController, :userinfo)
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through([:browser, :fetch_current_user])

    get("/authorize", AuthorizeController, :authorize)
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, error) do
    BorutaIdentityWeb.Router.handle_errors(conn, error)
  end
end
