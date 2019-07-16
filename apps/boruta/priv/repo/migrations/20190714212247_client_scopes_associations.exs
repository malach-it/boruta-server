defmodule Boruta.Repo.Migrations.ClientScopesAssociations do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      remove(:authorized_scopes)
    end

    create table(:clients_scopes) do
      add(:client_id, :uuid)
      add(:scope_id, :uuid)
    end
  end
end
