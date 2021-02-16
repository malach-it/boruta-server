defmodule BorutaWeb.Router do
  use BorutaWeb, :router

  import BorutaIdentityWeb.Sessions, only: [
    fetch_current_user: 2
  ]
  import BorutaWeb.Authorization, only: [
    require_authenticated: 2
  ]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :protected do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json", "jwt"]
  end

  pipeline :authenticated_api do
    plug :require_authenticated
  end

  get "/healthcheck", BorutaWeb.MonitoringController, :healthcheck

  scope "/accounts" do
    pipe_through [:browser, :fetch_current_user]

    get "/choose-session", BorutaWeb.ChooseSessionController, :new
  end

  scope "/accounts" do
    pipe_through :browser

    forward "/", BorutaIdentityWeb.Endpoint
  end

  scope "/", BorutaWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/oauth", BorutaWeb do
    pipe_through :api

    post "/revoke", OauthController, :revoke
    post "/token", OauthController, :token
    post "/introspect", OauthController, :introspect

    scope "/api", Admin, as: :admin do
      pipe_through :authenticated_api

      resources "/scopes", ScopeController, except: [:new, :edit]
      resources "/clients", ClientController, except: [:new, :edit]
      get "/users/current", UserController, :current
      # TODO user scopes
      # resources "/users/:user_id/scopes, only: [:create, :delete]

      # TODO remove users resource
      resources "/users", UserController, except: [:new, :edit, :create]
      resources "/upstreams", UpstreamController, except: [:new, :edit]
    end
  end

  scope "/oauth", BorutaWeb do
    pipe_through [:browser, :fetch_current_user]

    get "/authorize", OauthController, :authorize
  end

  scope "/admin", BorutaWeb do
    pipe_through :browser

    match :get, "/*path", PageController, :admin
  end
end
