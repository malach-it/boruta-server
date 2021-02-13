defmodule BorutaWeb.MonitoringController do
  use BorutaWeb, :controller

  plug Phoenix.Ecto.CheckRepoStatus, [otp_app: :boruta_web] when action in [:healthcheck]

  def healthcheck(conn, _params) do
    send_resp(conn, 204, "")
  end
end
