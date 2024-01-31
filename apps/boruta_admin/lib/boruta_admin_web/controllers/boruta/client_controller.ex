defmodule BorutaAdminWeb.ClientController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias BorutaAuth.KeyPairs
  alias BorutaAuth.KeyPairs.KeyPair
  alias BorutaIdentity.IdentityProviders

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
    identity_provider_id = get_in(client_params, ["identity_provider", "id"])

    BorutaAuth.Repo.transaction(fn ->
      with {:ok, client} <- Admin.create_client(client_params),
           {:ok, client} <- insert_global_key_pair(client, client_params["key_pair_id"]),
           {:ok, _client_identity_provider} <-
             IdentityProviders.upsert_client_identity_provider(
               client.id,
               identity_provider_id
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
         {:ok, %Client{} = client} <- update_client(client, client_params),
         {:ok, client} <- insert_global_key_pair(client, client_params["key_pair_id"]) do
      render(conn, "show.json", client: client)
    end
  end

  defp update_client(
         client,
         %{"identity_provider" => %{"id" => identity_provider_id}} = client_params
       ) do
    BorutaWeb.Repo.transaction(fn ->
      with {:ok, client} <- Admin.update_client(client, client_params),
           {:ok, _client_identity_provider} <-
             IdentityProviders.upsert_client_identity_provider(
               client.id,
               identity_provider_id
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

  def regenerate_key_pair(conn, %{"id" => client_id}) do
    client = get_client(client_id)

    with :ok <- ensure_open_for_edition(client_id),
         {:ok, client} <- Admin.regenerate_client_key_pair(client) do
      render(conn, "show.json", client: client)
    end
  end

  def delete(conn, %{"id" => client_id}) do
    with :ok <- ensure_open_for_edition(client_id),
         {:ok, _result} <- delete_client_multi(client_id) do
      send_resp(conn, :no_content, "")
    else
      {:error, :protected_resource} ->
        {:error, :protected_resource}

      {:error, _failed_operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp get_client(client_id) do
    Admin.get_client!(client_id)
  end

  # TODO protect public client
  defp ensure_open_for_edition(client_id) do
    admin_ui_client_id =
      System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")

    case client_id do
      ^admin_ui_client_id -> {:error, :protected_resource}
      _ -> :ok
    end
  end

  defp delete_client_multi(client_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:delete_client, fn _repo, _changes ->
      client = get_client(client_id)
      Admin.delete_client(client)
    end)
    |> Ecto.Multi.run(:delete_client_identity_provider_association, fn _repo, _changes ->
      IdentityProviders.remove_client_identity_provider(client_id)
    end)
    |> BorutaAuth.Repo.transaction()
  end

  defp insert_global_key_pair(%Client{} = client, nil), do: {:ok, client}
  defp insert_global_key_pair(%Client{} = client, key_pair_id) do
    %KeyPair{public_key: public_key, private_key: private_key} =
      KeyPairs.get_key_pair!(key_pair_id)

    Admin.regenerate_client_key_pair(client, public_key, private_key)
  end
end
