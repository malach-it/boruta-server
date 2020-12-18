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

  scope "/accounts" do
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

    post "/revoke", OauthController, :revoke
    post "/token", OauthController, :token
    post "/introspect", OauthController, :introspect

    scope "/api", Admin, as: :admin do
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
    pipe_through :browser

    get "/authorize", OauthController, :authorize
  end

  scope "/admin", BorutaWeb do
    pipe_through :browser

    match :get, "/*path", PageController, :admin
  end
end
