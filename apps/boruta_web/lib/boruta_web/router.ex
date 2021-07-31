defmodule BorutaWeb.Router do
  use BorutaWeb, :router

  import BorutaIdentityWeb.Sessions,
    only: [
      fetch_current_user: 2
    ]

  import BorutaWeb.Authorization, only: [
    require_authenticated: 2
  ]

  pipeline :protected_api do
    plug :accepts, ["json"]

    plug :require_authenticated
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
    plug(:accepts, ["json", "jwt"])
  end

  get("/healthcheck", BorutaWeb.MonitoringController, :healthcheck)


  scope "/accounts" do
    pipe_through([:browser, :fetch_current_user])

    get("/choose-session", BorutaWeb.ChooseSessionController, :new)
  end

  forward("/accounts", BorutaIdentityWeb.Endpoint)

  scope "/oauth", BorutaWeb do
    pipe_through(:api)

    get "/jwks", OpenidController, :jwks_index
    get "/jwks/:client_id", OpenidController, :jwks_show
  end

  scope "/oauth", BorutaWeb do
    pipe_through(:protected_api)

    get "/userinfo", OpenidController, :userinfo
    post "/userinfo", OpenidController, :userinfo
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through(:api)

    post("/token", TokenController, :token)
    post("/revoke", RevokeController, :revoke)
    post("/introspect", IntrospectController, :introspect)
  end

  scope "/oauth", BorutaWeb.Oauth do
    pipe_through([:browser, :fetch_current_user])

    get("/authorize", AuthorizeController, :authorize)
  end
end
