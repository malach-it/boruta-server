defmodule BorutaIdentity.Repo.Migrations.AddAccountTypeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :account_type, :string
    end
  end
end
