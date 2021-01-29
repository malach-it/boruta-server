defmodule BorutaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_web

  socket "/socket", BorutaWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :boruta_web,
    gzip: false,
    only: ~w(admin accounts css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug :put_secret_key_base
  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, Application.get_env(:boruta_web, BorutaWeb.Endpoint)[:secret_key_base]
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_boruta_web_key",
    signing_salt: "OCKBuS86"

  plug BorutaWeb.Router
end
