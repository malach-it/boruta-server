defmodule BorutaGateway.Repo.Migrations.AddUnauthorizedResponseToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :unauthorized_response, :text
    end
  end
end
