defmodule BorutaWeb.Repo.Migrations.AddDefaultRedirectUrisToClients do
  use Ecto.Migration

  import Ecto.Query

  alias Boruta.Ecto.Client
  alias BorutaWeb.Repo

  def change do
    from(c in Client, where: is_nil(c.redirect_uris))
    |> Repo.update_all(set: [redirect_uris: []])

    alter table(:clients) do
      modify :redirect_uris, {:array, :string}, null: false, default: []
    end
  end
end
