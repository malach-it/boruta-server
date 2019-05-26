defmodule Boruta.Repo.Migrations.AddClientIdToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :client_id, :uuid
    end
  end
end
