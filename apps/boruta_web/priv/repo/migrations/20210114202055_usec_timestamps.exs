defmodule Boruta.Repo.Migrations.UsecTimestamps do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end
  end
end
