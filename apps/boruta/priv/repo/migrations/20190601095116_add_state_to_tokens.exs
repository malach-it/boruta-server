defmodule Boruta.Repo.Migrations.AddStateToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:state, :string)
    end
  end
end
