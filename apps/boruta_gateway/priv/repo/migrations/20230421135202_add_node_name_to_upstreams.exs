defmodule BorutaGateway.Repo.Migrations.AddNodeNameToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :node_name, :string, default: "global"
    end
  end
end
