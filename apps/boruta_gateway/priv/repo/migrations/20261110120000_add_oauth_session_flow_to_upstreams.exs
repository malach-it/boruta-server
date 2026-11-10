defmodule BorutaGateway.Repo.Migrations.AddOauthSessionFlowToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add(:oauth_session_flow, :string, null: false, default: "verifiable_presentation")
    end
  end
end
