defmodule Boruta.Repo.Migrations.RemoveClientsSecretConstraint do
  use Ecto.Migration

  def change do
    drop(unique_index(:tokens, [:value, :name]))
    drop(unique_index(:clients, [:secret]))
  end
end
