defmodule Boruta.Repo.Migrations.AddScopeToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:scope, :string)
    end
  end
end
