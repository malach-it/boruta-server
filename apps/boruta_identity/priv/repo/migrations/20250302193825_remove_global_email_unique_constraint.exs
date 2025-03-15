defmodule BorutaIdentity.Repo.Migrations.RemoveGlobalEmailUniqueConstraint do
  use Ecto.Migration

  def change do
    execute("DROP INDEX users_email_index")
  end
end
