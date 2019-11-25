defmodule BorutaWeb.Router do
  use BorutaWeb, :router

  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, otp_app: :boruta_web

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
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser

    get "/choose-session", BorutaWeb.ChooseSessionController, :new
    pow_routes()
    pow_extension_routes()
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
    resources "/users", UserController, except: [:new, :edit, :create]
  end

  scope "/admin", BorutaWeb do
    pipe_through :browser

    match :get, "/*path", PageController, :admin
  end
end
