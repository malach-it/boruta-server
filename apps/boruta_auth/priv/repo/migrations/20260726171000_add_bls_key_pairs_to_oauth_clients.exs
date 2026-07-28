defmodule BorutaAuth.Repo.Migrations.AddBlsKeyPairsToOauthClients do
  use Ecto.Migration

  alias BorutaAuth.BlsKeyPair

  def up do
    create table(:oauth_clients_bls_key_pairs, primary_key: false) do
      add(
        :client_id,
        references(:oauth_clients, type: :binary_id, on_delete: :delete_all),
        primary_key: true
      )

      add(:private_key, :binary, null: false)
      add(:public_key, :binary, null: false)
      add(:did_key, :text, null: false)

      timestamps()
    end

    create(unique_index(:oauth_clients_bls_key_pairs, [:did_key]))

    flush()

    repo().query!("SELECT id FROM oauth_clients").rows
    |> Enum.each(fn [client_id] ->
      key_pair = BlsKeyPair.generate()

      repo().query!(
        """
        INSERT INTO oauth_clients_bls_key_pairs
          (client_id, private_key, public_key, did_key, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, NOW(), NOW())
        """,
        [client_id, key_pair.private_key, key_pair.public_key, key_pair.did_key],
        log: false
      )
    end)
  end

  def down do
    drop(table(:oauth_clients_bls_key_pairs))
  end
end
