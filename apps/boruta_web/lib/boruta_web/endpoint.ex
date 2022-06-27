defmodule BorutaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_web

  @session_options [
    store: :cookie,
    key: "_boruta_web_key",
    signing_salt: "OCKBuS86"
  ]

  plug Plug.Static,
    at: "/",
    from: :boruta_web,
    gzip: false,
    only: ~w(admin accounts css fonts images js favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :boruta_web
  end

  plug Plug.RequestId
  plug Plug.Telemetry,
    event_prefix: [:boruta_web, :endpoint],
    log: {__MODULE__, :log_level, []}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug :put_secret_key_base
  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, Application.get_env(:boruta_web, BorutaWeb.Endpoint)[:secret_key_base]
  end

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug BorutaWeb.Router

  def log_level(%{path_info: ["healthcheck" | _]}), do: false
  def log_level(%{private: %{BorutaIdentityWeb.Router => {["accounts"], _}}}), do: false # logs are handled by boruta_identity
  def log_level(_), do: :info
end
