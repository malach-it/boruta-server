defmodule BorutaAdminWeb.UserView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.BackendView
  alias BorutaAdminWeb.ChangesetView
  alias BorutaAdminWeb.UserView
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Accounts.UserRole

  def render("index.json", %{
        users: users,
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      data: render_many(users, UserView, "user.json"),
      page_number: page_number,
      page_size: page_size,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      uid: user.uid,
      email: user.username,
      totp_registered_at: user.totp_registered_at,
      metadata: user.metadata,
      group: user.group,
      authorized_scopes: Accounts.get_user_scopes(user.id),
      roles:
        Accounts.get_user_roles(user.id)
        |> Enum.filter(fn
          %Role{id: id} ->
            Enum.find(user.roles, fn %UserRole{role_id: role_id} -> role_id == id end)

          _ ->
            false
        end),
      backend: render_one(user.backend, BackendView, "backend.json", backend: user.backend)
    }
  end

  def render("import_result.json", %{import_result: import_result}) do
    import_result
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.Scope do
    def encode(scope, opts) do
      Jason.Encode.map(Map.take(scope, [:id, :name, :public]), opts)
    end
  end

  defimpl Jason.Encoder, for: BorutaIdentity.Accounts.Role do
    def encode(role, opts) do
      Jason.Encode.map(Map.take(role, [:id, :name, :scopes]), opts)
    end
  end

  defimpl Jason.Encoder, for: Ecto.Changeset do
    def encode(changeset, _opts) do
      changeset
      |> ChangesetView.translate_errors()
      |> Jason.encode!()
    end
  end
end
