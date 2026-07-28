defmodule BorutaIdentity.Repo.Migrations.AddBlsKeyPairToUsers do
  use Ecto.Migration

  alias BorutaAuth.BlsKeyPair

  def up do
    alter table(:users) do
      add :bls_private_key, :binary
      add :bls_public_key, :binary
      add :bls_did_key, :text
    end

    flush()

    repo().query!("SELECT id FROM users").rows
    |> Enum.each(fn [id] ->
      key_pair = BlsKeyPair.generate()

      repo().query!(
        """
        UPDATE users
        SET bls_private_key = $1, bls_public_key = $2, bls_did_key = $3
        WHERE id = $4
        """,
        [key_pair.private_key, key_pair.public_key, key_pair.did_key, id],
        log: false
      )
    end)

    alter table(:users) do
      modify :bls_private_key, :binary, null: false
      modify :bls_public_key, :binary, null: false
      modify :bls_did_key, :text, null: false
    end

    create unique_index(:users, [:bls_did_key])
  end

  def down do
    drop index(:users, [:bls_did_key])

    alter table(:users) do
      remove :bls_private_key
      remove :bls_public_key
      remove :bls_did_key
    end
  end
end
