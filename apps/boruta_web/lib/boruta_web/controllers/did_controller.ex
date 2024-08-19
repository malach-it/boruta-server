defmodule BorutaWeb.DidController do
  alias Boruta.BasicAuth
  use BorutaWeb, :controller

  alias Boruta.ClientsAdapter
  alias Boruta.VerifiableCredentials

  def resolve_status(conn, %{"status" => salt}) do
    case conn |> get_req_header("authorization") |> List.first() |> BasicAuth.decode() |> dbg do
      {:ok, [did, _]} ->
        client = ClientsAdapter.get_client_by_did(did)

        status = VerifiableCredentials.verify_salt(client.private_key, salt)

        send_resp(conn, 200, Atom.to_string(status))

      _ ->
        send_resp(conn, 400, "Bad request")
    end
  end
end
