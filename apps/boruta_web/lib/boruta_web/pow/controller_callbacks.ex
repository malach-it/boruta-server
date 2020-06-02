defmodule BorutaWeb.Pow.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  import Plug.Conn

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    conn = put_session(conn, :session_chosen, true)

    {:ok, conn}
  end
end
