defmodule BorutaAdminWeb.KeyPairController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaAuth.KeyPairs
  alias BorutaAuth.KeyPairs.KeyPair

  plug(:authorize, ["clients:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, _params) do
    key_pairs = KeyPairs.list_key_pairs()
    render(conn, "index.json", key_pairs: key_pairs)
  end

  def create(conn, %{"key_pair" => key_pair_params}) do
    with {:ok, %KeyPair{} = key_pair} <- KeyPairs.create_key_pair(key_pair_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_key_pair_path(conn, :show, key_pair))
      |> render("show.json", key_pair: key_pair)
    end
  end

  def show(conn, %{"id" => id}) do
    key_pair = KeyPairs.get_key_pair!(id)
    render(conn, "show.json", key_pair: key_pair)
  end

  def rotate(conn, %{"id" => id}) do
    key_pair = KeyPairs.get_key_pair!(id)

    with {:ok, key_pair} <- KeyPairs.rotate(key_pair) do
      render(conn, "show.json", key_pair: key_pair)
    end
  end

  def update(conn, %{"id" => id, "key_pair" => key_pair_params}) do
    key_pair = KeyPairs.get_key_pair!(id)

    with {:ok, %KeyPair{} = key_pair} <- KeyPairs.update_key_pair(key_pair, key_pair_params) do
      render(conn, "show.json", key_pair: key_pair)
    end
  end

  def delete(conn, %{"id" => id}) do
    key_pair = KeyPairs.get_key_pair!(id)

    with {:ok, _key_pair} <- KeyPairs.delete_key_pair(key_pair) do
      send_resp(conn, :no_content, "")
    end
  end
end
