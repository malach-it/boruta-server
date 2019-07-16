defmodule Boruta.Repo.Migrations.ScopesConstraints do
  use Ecto.Migration

  def change do
    create unique_index(:scopes, [:name])

    alter table(:clients_scopes) do
      modify(:client_id, references("clients", type: :uuid, on_delete: :delete_all), from: :uuid)
      modify(:scope_id, references("scopes", type: :uuid, on_delete: :delete_all), from: :uuid)
    end
  end
end
