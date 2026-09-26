defmodule BorutaWeb.DidController do
  use BorutaWeb, :controller

  alias Boruta.Oauth.Client
  alias Boruta.Openid.VerifiableCredentials

  def resolve_status(conn, %{"status" => salt}) do
    clients = Boruta.Ecto.Admin.list_clients()

    status =
      Enum.reduce_while(clients, :invaild, fn client, _acc ->
        did =
          case client.did do
            nil ->
              Client.Crypto.kid_from_private_key(client.private_key)

            did ->
              did <> "#" <> String.replace(did, "did:key:", "")
          end

        case VerifiableCredentials.Status.verify_status_token(did, salt) do
          :expired -> {:cont, :expired}
          :invalid -> {:cont, :invalid}
          status -> {:halt, status}
        end
      end)

    send_resp(conn, 200, Atom.to_string(status))
  end
end
