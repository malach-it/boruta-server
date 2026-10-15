defmodule BorutaGateway.Repo.Migrations.DefaultUpstreamErrorContentTypeToJson do
  use Ecto.Migration

  def up do
    alter table(:upstreams) do
      modify(:error_content_type, :string, default: "application/json")
    end
  end

  def down do
    alter table(:upstreams) do
      modify(:error_content_type, :string)
    end
  end
end
