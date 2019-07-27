defmodule BorutaWeb.Router do
  use BorutaWeb, :router
  use Coherence.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Coherence.Authentication.Session
  end

  pipeline :protected do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Coherence.Authentication.Session, protected: true
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser
    coherence_routes()
  end

  scope "/" do
    pipe_through :protected
    coherence_routes :protected
  end

  scope "/", BorutaWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/oauth", BorutaWeb do
    pipe_through :api

    post "/token", OauthController, :token
    post "/introspect", OauthController, :introspect
  end

  scope "/oauth", BorutaWeb do
    pipe_through :browser

    get "/authorize", OauthController, :authorize
  end

  scope "/api", BorutaWeb.Admin, as: :admin do
    pipe_through :api

    resources "/scopes", ScopeController, except: [:new, :edit]
    resources "/clients", ClientController, except: [:new, :edit]
    get "/users/current", UserController, :current
    resources "/users", UserController, except: [:new, :edit, :create, :update]
  end

  scope "/admin", BorutaWeb do
    pipe_through :browser

    match :get, "/*path", PageController, :admin
  end
end
