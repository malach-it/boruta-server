defmodule Boruta.Repo.Migrations.AddUniqueTokenValueConstraint do
  use Ecto.Migration

  def change do
    create index("tokens", [:value])
    create unique_index("tokens", [:client_id, :value])
  end
end
