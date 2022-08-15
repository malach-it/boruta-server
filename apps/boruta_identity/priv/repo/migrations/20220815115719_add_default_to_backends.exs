defmodule BorutaIdentity.Repo.Migrations.AddDefaultToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :is_default, :boolean, default: false, null: false
    end
    execute("""
      UPDATE backends SET is_default = true
        WHERE id = (SELECT id FROM backends LIMIT 1)
    """)
  end
end
