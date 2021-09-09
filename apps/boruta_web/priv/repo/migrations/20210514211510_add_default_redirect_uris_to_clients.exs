defmodule BorutaWeb.Repo.Migrations.AddDefaultRedirectUrisToClients do
  use Ecto.Migration

  import Ecto.Query

  alias Boruta.Ecto.Client
  alias BorutaWeb.Repo

  def change do
    alter table(:clients) do
      modify :redirect_uris, {:array, :string}, null: false, default: [], using: "array[redirect_uri]"
    end
  end
end
