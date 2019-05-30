defmodule Boruta.Repo.Migrations.RenameTokensName do
  use Ecto.Migration

  def change do
    rename table(:tokens), :name, to: :type
  end
end
