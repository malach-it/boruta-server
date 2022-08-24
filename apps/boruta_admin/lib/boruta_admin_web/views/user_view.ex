defmodule BorutaAdminWeb.UserView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.ChangesetView
  alias BorutaAdminWeb.IdentityProviderView
  alias BorutaAdminWeb.UserView
  alias BorutaIdentity.Accounts

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
      email: user.username,
      authorized_scopes: Accounts.get_user_scopes(user.id),
      backend:
        render_one(user.backend, IdentityProviderView, "backend.json", backend: user.backend)
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

  defimpl Jason.Encoder, for: Ecto.Changeset do
    def encode(changeset, _opts) do
      changeset
      |> ChangesetView.translate_errors()
      |> Jason.encode!()
    end
  end
end
