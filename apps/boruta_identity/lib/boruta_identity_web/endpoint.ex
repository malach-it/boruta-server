defmodule BorutaIdentityWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_identity

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug RemoteIp

  plug Plug.Static,
    at: "/",
    from: :boruta_identity,
    gzip: false,
    only: ~w(images wallet manifest.json favicon.ico robots.txt semantic-ui.min.css)

  plug Plug.RequestId

  plug Plug.Telemetry,
    event_prefix: [:boruta_identity, :endpoint],
    log: {__MODULE__, :log_level, []}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug :put_configured_session
  plug BorutaIdentityWeb.Router

  def put_configured_session(conn, _) do
    Plug.Session.call(conn, Plug.Session.init(session_options()))
  end

  defp session_options do
    endpoint_config = Application.get_env(:boruta_identity, BorutaIdentityWeb.Endpoint)

    [
      store: :cookie,
      key: endpoint_config[:session_cookie_key],
      signing_salt: endpoint_config[:session_cookie_signing_salt],
      secure: true,
      same_site: "Lax"
    ]
  end

  def log_level(%{path_info: ["healthcheck" | _]}), do: false
  def log_level(_), do: :info
end
