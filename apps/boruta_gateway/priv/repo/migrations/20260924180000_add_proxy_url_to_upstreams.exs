defmodule BorutaGateway.Repo.Migrations.AddProxyUrlToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:proxy_url, :string)
    end
  end
end
