defmodule BorutaIdentity.Repo.Migrations.AddCodeVerifierToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :code_verifier, :string, null: false, default: fragment("gen_random_uuid()")
    end
  end
end
