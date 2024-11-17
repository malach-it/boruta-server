defmodule BorutaAdminWeb.UserController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.Accounts.LdapError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Admin
  alias BorutaIdentity.IdentityProviders

  plug(:authorize, ["users:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, params) do
    users =
      case params["q"] do
        nil -> Admin.list_users(params)
        query -> Admin.search_users(query, params)
      end

    render(conn, "index.json",
      users: users.entries,
      page_number: users.page_number,
      page_size: users.page_size,
      total_pages: users.total_pages,
      total_entries: users.total_entries
    )
  end

  def show(conn, %{"id" => id}) do
    case Admin.get_user(id) do
      %User{} = user ->
        render(conn, "show.json", user: user)

      nil ->
        {:error, :not_found}
    end
  end

  def create(conn, %{"backend_id" => backend_id, "user" => user_params}) do
    create_params = %{
      username: user_params["email"],
      group: user_params["group"],
      password: user_params["password"],
      metadata: user_params["metadata"] || %{},
      authorized_scopes: user_params["authorized_scopes"],
      organizations: user_params["organizations"],
      roles: user_params["roles"]
    }

    backend = IdentityProviders.get_backend!(backend_id)

    with {:ok, user} <- Admin.create_user(backend, create_params) do
      render(conn, "show.json", user: user)
    end
  rescue
    _e in Ecto.NoResultsError ->
      {:error,
       Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:backend, "does not exist")}

    error in LdapError ->
      {:error,
       Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:backend, error.message)}
  end

  def create(conn, %{"backend_id" => backend_id, "file" => file_params} = import_params) do
    backend = IdentityProviders.get_backend!(backend_id)

    import_users_opts =
      (import_params["options"] || %{})
      |> Enum.map(fn
        {"metadata_headers" = k, v} -> {String.to_atom(k), v}
        {"username_header" = k, v} -> {String.to_atom(k), v}
        {"password_header" = k, v} -> {String.to_atom(k), v}
        {"hash_password" = k, "true"} -> {String.to_atom(k), true}
        {"hash_password" = k, "false"} -> {String.to_atom(k), false}
        {"hash_password" = k, v} when is_boolean(v) -> {String.to_atom(k), v}
        {_k, _v} -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    case file_params do
      %Plug.Upload{} ->
        result = Admin.import_users(backend, file_params.path, import_users_opts)

        render(conn, "import_result.json", import_result: result)

      _ ->
        {:error, Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:file, "is invalid")}
    end
  rescue
    _e in Ecto.NoResultsError ->
      {:error,
       Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:backend, "does not exist")}

    error in LdapError ->
      {:error,
       Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:backend, error.message)}
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def update(conn, %{"id" => id, "user" => user_params}) do
    update_params = %{
      username: user_params["email"],
      group: user_params["group"],
      metadata: user_params["metadata"] || %{},
      authorized_scopes: user_params["authorized_scopes"],
      organizations: user_params["organizations"],
      roles: user_params["roles"]
    }

    with :ok <- ensure_open_for_edition(id, conn),
         %User{} = user <- Admin.get_user(id),
         # TODO update user email and password
         {:ok, %User{} = user} <- Admin.update_user(user, update_params) do
      render(conn, "show.json", user: user)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update(_conn, _params), do: {:error, :bad_request}

  def delete(conn, %{"id" => user_id}) do
    with :ok <- ensure_open_for_edition(user_id, conn),
         {:ok, _user} <- Admin.delete_user(user_id) do
      send_resp(conn, 204, "")
    else
      {:error, "" <> reason} ->
        {:error, Ecto.Changeset.change(%User{}) |> Ecto.Changeset.add_error(:backend, reason)}

      error ->
        error
    end
  end

  defp ensure_open_for_edition(user_id, conn) do
    %{"sub" => sub} = conn.assigns[:authorization]

    case user_id == sub do
      true -> {:error, :protected_resource}
      false -> :ok
    end
  end
end
