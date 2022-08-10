defmodule BorutaGateway.Repo.Migrations.AddForbiddenResponseToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :forbidden_response, :text
    end
  end
end
