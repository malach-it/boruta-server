defmodule Boruta.Repo.Migrations.CreateUpstreams do
  use Ecto.Migration

  def change do
    create table(:upstreams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scheme, :string
      add :host, :string
      add :port, :integer
      add :uris, {:array, :string}, default: []
      add :strip_uri, :boolean, default: false
      add :authorize, :boolean, default: false
      add :required_scopes, {:array, :string}, default: []

      timestamps()
    end
  end
end
