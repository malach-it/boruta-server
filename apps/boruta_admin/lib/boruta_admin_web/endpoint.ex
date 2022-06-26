defmodule BorutaAdminWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_admin

  # sets the same session as :boruta_web
  @session_options [
    store: :cookie,
    key: "_boruta_web_key",
    signing_salt: "OCKBuS86",
    extra: "SameSite=None; Secure"
  ]

  plug Plug.Static,
    at: "/",
    from: :boruta_admin,
    gzip: false,
    only: ~w(assets)

  socket "/socket", BorutaAdminWeb.UserSocket,
    websocket: true,
    longpoll: false

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :boruta_admin
  end

  plug Plug.RequestId
  plug Plug.Telemetry,
    event_prefix: [:boruta_admin, :endpoint],
    log: {__MODULE__, :log_level, []}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug BorutaAdminWeb.Router

  def log_level(%{path_info: ["healthcheck" | _]}), do: false
  def log_level(%{path_info: ["favicon.ico" | _]}), do: false
  def log_level(_), do: :info
end
