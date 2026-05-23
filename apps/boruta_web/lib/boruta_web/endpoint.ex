defmodule BorutaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_web

  plug RemoteIp

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
    put_in(
      conn.secret_key_base,
      Application.get_env(:boruta_web, BorutaWeb.Endpoint)[:secret_key_base]
    )
  end

  plug Plug.MethodOverride
  plug Plug.Head
  plug :put_configured_session
  plug CORSPlug
  plug BorutaWeb.Router

  def put_configured_session(conn, _) do
    Plug.Session.call(conn, Plug.Session.init(session_options()))
  end

  defp session_options do
    endpoint_config = Application.get_env(:boruta_web, BorutaWeb.Endpoint)

    [
      store: :cookie,
      key: endpoint_config[:session_cookie_key],
      signing_salt: endpoint_config[:session_cookie_signing_salt]
    ]
  end

  # logs are handled by boruta_identity
  def log_level(%{private: %{BorutaIdentityWeb.Router => {["accounts"], _}}}), do: false
  def log_level(%{path_info: ["healthcheck" | _]}), do: false

  def log_level(%{path_info: path_info}) do
    case Enum.member?(path_info, "images") do
      true -> false
      false -> :info
    end
  end
end
