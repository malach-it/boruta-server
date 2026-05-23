defmodule BorutaAdminWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boruta_admin

  plug RemoteIp

  plug Plug.Static,
    at: "/",
    from: :boruta_admin,
    gzip: false,
    only: ~w(assets favicon.ico semantic-ui.min.css prism-dark.min.css themes)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :boruta_admin
  end

  plug Plug.RequestId
  plug BorutaAdminWeb.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug :put_configured_session
  plug BorutaAdminWeb.Router

  def put_configured_session(conn, _) do
    Plug.Session.call(conn, Plug.Session.init(session_options()))
  end

  defp session_options do
    endpoint_config = Application.get_env(:boruta_admin, BorutaAdminWeb.Endpoint)

    [
      store: :cookie,
      key: endpoint_config[:session_cookie_key],
      signing_salt: endpoint_config[:session_cookie_signing_salt]
    ]
  end

  def log_level(%{path_info: ["healthcheck" | _]}), do: false
  def log_level(%{path_info: ["favicon.ico" | _]}), do: false
  def log_level(_), do: :info
end
