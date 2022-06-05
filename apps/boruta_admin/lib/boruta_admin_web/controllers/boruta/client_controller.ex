defmodule BorutaAdminWeb.ClientController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias BorutaIdentity.RelyingParties

  plug(:authorize, ["clients:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, _params) do
    clients = Admin.list_clients()

    render(conn, "index.json", clients: clients)
  end

  def create(conn, %{"client" => client_params}) do
    with {:ok, %Client{} = client} <- create_client(client_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_client_path(conn, :show, client))
      |> render("show.json", client: client)
    end
  end

  defp create_client(client_params) do
    relying_party_id = get_in(client_params, ["relying_party", "id"])

    BorutaAuth.Repo.transaction(fn ->
      with {:ok, client} <- Admin.create_client(client_params),
           {:ok, _client_relying_party} <-
             RelyingParties.upsert_client_relying_party(
               client.id,
               relying_party_id
             ) do
        client
      else
        {:error, error} ->
          BorutaAuth.Repo.rollback(error)
      end
    end)
  end

  def show(conn, %{"id" => client_id}) do
    client = get_client(client_id)

    render(conn, "show.json", client: client)
  end

  def update(conn, %{"id" => client_id, "client" => client_params}) do
    client = get_client(client_id)

    with :ok <- ensure_open_for_edition(client_id),
         {:ok, %Client{} = client} <- update_client(client, client_params) do
      render(conn, "show.json", client: client)
    end
  end

  defp update_client(client, %{"relying_party" => %{"id" => relying_party_id}} = client_params) do
    BorutaWeb.Repo.transaction(fn ->
      with {:ok, client} <- Admin.update_client(client, client_params),
           {:ok, _client_relying_party} <-
             RelyingParties.upsert_client_relying_party(
               client.id,
               relying_party_id
             ) do
        client
      else
        {:error, error} ->
          BorutaWeb.Repo.rollback(error)
      end
    end)
  end

  defp update_client(client, client_params) do
    Admin.update_client(client, client_params)
  end

  def delete(conn, %{"id" => client_id}) do
    client = get_client(client_id)

    with :ok <- ensure_open_for_edition(client_id),
         {:ok, %Client{}} <- Admin.delete_client(client),
         {:ok, _client_relying_party} <- RelyingParties.remove_client_relying_party(client_id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_client(client_id) do
    Admin.get_client!(client_id)
  end

  defp ensure_open_for_edition(client_id) do
    admin_ui_client_id =
      System.get_env("VUE_APP_ADMIN_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")

    case client_id do
      ^admin_ui_client_id -> {:error, :protected_resource}
      _ -> :ok
    end
  end
end
