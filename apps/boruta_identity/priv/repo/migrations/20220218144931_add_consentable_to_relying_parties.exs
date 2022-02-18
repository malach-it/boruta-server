defmodule BorutaIdentity.Repo.Migrations.AddConsentableToRelyingParties do
  use Ecto.Migration

  def change do
    alter table(:relying_parties) do
      add :consentable, :boolean, default: false, null: false
    end
  end
end
