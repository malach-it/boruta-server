defmodule BorutaWeb.Repo.Migrations.AddDefaultRedirectUrisToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      modify(:redirect_uris, {:array, :string},
        null: false,
        default: [],
        using: "array[redirect_uri]"
      )
    end
  end
end
