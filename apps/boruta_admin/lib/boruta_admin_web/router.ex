defmodule BorutaAdminWeb.Router do
  use BorutaAdminWeb, :router
  use Plug.ErrorHandler

  alias Plug.Conn.Status

  import BorutaAdminWeb.Authorization,
    only: [
      require_authenticated: 2
    ]

  pipeline :authenticated_api do
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

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", BorutaAdminWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
  end

  scope "/api", BorutaAdminWeb, as: :admin do
    pipe_through(:authenticated_api)

    resources("/logs", LogsController, only: [:index])
    resources("/scopes", ScopeController, except: [:new, :edit])
    resources("/roles", RoleController, except: [:new, :edit])
    resources("/key-pairs", KeyPairController, except: [:new, :edit])
    post("/key-pairs/:id/rotate", KeyPairController, :rotate)
    resources("/clients", ClientController, except: [:new, :edit])
    post("/clients/:id/regenerate_key_pair", ClientController, :regenerate_key_pair)
    resources("/users", UserController, except: [:new, :edit])
    resources("/organizations", OrganizationController, except: [:new, :edit])
    get("/upstreams/nodes", UpstreamController, :node_list)
    resources("/upstreams", UpstreamController, except: [:new, :edit])

    scope "/configuration", as: :configuration do
      get("/", ConfigurationController, :configuration, as: :configuration_list)

      post("/upload-configuration-file", ConfigurationController, :upload_configuration_file,
        as: :upload_configuration_file
      )

      get("/error-templates/:template_type", ConfigurationController, :error_template,
        as: :error_template
      )

      patch("/error-templates/:template_type", ConfigurationController, :update_error_template,
        as: :error_template
      )

      delete("/error-templates/:template_type", ConfigurationController, :delete_error_template,
        as: :error_template
      )
    end

    resources "/identity-providers", IdentityProviderController, except: [:new, :edit] do
      get("/templates/:template_type", IdentityProviderController, :template, as: :template)

      patch("/templates/:template_type", IdentityProviderController, :update_template,
        as: :template
      )

      delete("/templates/:template_type", IdentityProviderController, :delete_template,
        as: :template
      )
    end
    resources "/backends", BackendController, except: [:new, :edit] do
      get("/email-templates/:template_type", BackendController, :email_template, as: :email_template)

      patch("/email-templates/:template_type", BackendController, :update_email_template,
        as: :email_template
      )

      delete("/email-templates/:template_type", BackendController, :delete_email_template,
        as: :email_template
      )
    end
  end

  scope "/", BorutaAdminWeb do
    pipe_through(:browser)

    match(:get, "/*path", PageController, :index)
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = %{
      code: Status.reason_atom(conn.status) |> Atom.to_string() |> String.upcase(),
      message: reason.__struct__.message(reason)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status, Jason.encode!(message))
  end
end
