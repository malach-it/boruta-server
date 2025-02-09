defmodule BorutaWeb.DidController do
  use BorutaWeb, :controller

  alias Boruta.VerifiableCredentials

  def resolve_status(conn, %{"status" => salt}) do
    clients = Boruta.Ecto.Admin.list_clients()
    status = Enum.reduce_while(clients, :invaild, fn client, _acc ->
      case VerifiableCredentials.Status.verify_status_token(client.private_key, salt) do
        :expired -> {:cont, :expired}
        :invalid -> {:cont, :invalid}
        status -> {:halt, status}
      end
    end)

    send_resp(conn, 200, Atom.to_string(status))
  end
end
