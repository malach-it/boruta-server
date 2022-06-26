defmodule BorutaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_web

  @session_options [
    store: :cookie,
    key: "_boruta_web_key",
    signing_salt: "OCKBuS86",
    extra: "SameSite=None; Secure"
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
  plug Plug.Telemetry, event_prefix: [:boruta_web, :endpoint]

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
end
