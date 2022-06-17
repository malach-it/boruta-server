defmodule BorutaAdminWeb.Router do
  use BorutaAdminWeb, :router

  import BorutaAdminWeb.Authorization, only: [
    require_authenticated: 2
  ]

  pipeline :authenticated_api do
    plug(:accepts, ["json"])
    plug :require_authenticated
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", BorutaAdminWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", BorutaAdminWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).

  scope "/api", BorutaAdminWeb, as: :admin do
    pipe_through(:authenticated_api)

    get("/users/current", UserController, :current)
    resources("/scopes", ScopeController, except: [:new, :edit])
    resources("/clients", ClientController, except: [:new, :edit])
    # TODO user scopes
    # resources "/users/:user_id/scopes, only: [:create, :delete]
    resources("/users", UserController, except: [:new, :edit, :create])
    resources("/upstreams", UpstreamController, except: [:new, :edit])
    resources "/identity-providers", IdentityProviderController, except: [:new, :edit] do
      get "/templates/:template_type", IdentityProviderController, :template, as: :template
      patch "/templates/:template_type", IdentityProviderController, :update_template, as: :template
      delete "/templates/:template_type", IdentityProviderController, :delete_template, as: :template
    end
  end

  scope "/", BorutaAdminWeb do
    pipe_through(:browser)

    match(:get, "/*path", PageController, :index)
  end
end
