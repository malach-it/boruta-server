defmodule BorutaGateway.Repo.Migrations.DefaultUpstreamErrorContentTypeToJson do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      modify(:error_content_type, :string, default: "application/json")
    end
  end
end
