defmodule BorutaIdentityWeb.Router do
  use BorutaIdentityWeb, :router
  use Plug.ErrorHandler

  import BorutaIdentityWeb.Sessions, only: [
    fetch_current_user: 2,
    redirect_if_user_is_authenticated: 2,
    require_authenticated_user: 2
  ]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # scope "/", BorutaIdentityWeb do
  #   pipe_through :browser

  #   get "/", PageController, :index
  # end

  ## Authentication routes

  scope "/", BorutaIdentityWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
  end

  scope "/", BorutaIdentityWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/choose_session", ChooseSessionController, :index
    get "/users/consent", UserConsentController, :index
    post "/users/consent", UserConsentController, :consent
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
  end

  scope "/", BorutaIdentityWeb do
    pipe_through [:browser]

    get "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  @error_templates %{
    400 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/400.mustache")
      |> File.read!(),
    403 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/403.mustache")
      |> File.read!(),
    404 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/404.mustache")
      |> File.read!(),
    500 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/500.mustache")
      |> File.read!()
  }

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{reason: reason}) do
    reason = %{
      message: reason.message
    }

    content = Mustachex.render(@error_templates[conn.status], %{reason: reason})
    send_resp(conn, conn.status, content)
  end
end
