defmodule Boruta.Repo.Migrations.Authable do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:secret, :string)
      add(:redirect_uri, :string)
      add(:settings, :jsonb)
      add(:priv_settings, :jsonb)
      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid))

      timestamps()
    end

    create table(:tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:value, :string)
      add(:expires_at, :integer)
      add(:details, :jsonb)
      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid))

      timestamps()
    end

    create(index(:tokens, [:user_id]))
    create(unique_index(:tokens, [:value, :name]))
    create(index(:clients, [:user_id]))
    create(unique_index(:clients, [:secret]))
    create(unique_index(:clients, [:name]))
  end
end
