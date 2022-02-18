defmodule Boruta.Repo.Migrations.AddLabelToScopes do
  use Ecto.Migration

  def change do
    alter table(:scopes) do
      add :label, :string
    end
  end
end
