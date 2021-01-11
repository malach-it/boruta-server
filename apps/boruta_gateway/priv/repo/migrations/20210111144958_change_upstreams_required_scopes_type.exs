defmodule BorutaGateway.Repo.Migrations.ChangeUpstreamsRequiredScopesType do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      remove :required_scopes
      add :required_scopes, :jsonb, default: "{}"
    end
  end
end
