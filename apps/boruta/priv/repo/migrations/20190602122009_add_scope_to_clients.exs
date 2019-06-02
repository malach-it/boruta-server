defmodule Boruta.Repo.Migrations.AddScopeToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add(:authorize_scope, :boolean, default: false)
      add(:authorized_scopes, {:array, :string}, default: [])
    end
  end
end
