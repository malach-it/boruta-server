defmodule BorutaGateway.Repo.Migrations.AddErrorContentTypeToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :error_content_type, :string
    end
  end
end
