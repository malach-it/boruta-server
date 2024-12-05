defmodule BorutaFederationWeb.Router do
  use BorutaFederationWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BorutaFederationWeb do
    pipe_through :api

    get "/", PageController, :index
    get "/resolve", ResolveController, :resolve
    get "/fetch", FetchController, :fetch
  end
end
