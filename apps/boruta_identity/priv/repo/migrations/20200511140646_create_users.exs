defmodule BorutaIdentity.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :string
      add :email, :string

      add :password_hash, :string
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
      add :failed_attempts, :integer, default: 0
      add :locked_at, :utc_datetime
      add :sign_in_count, :integer, default: 0
      add :current_sign_in_at, :utc_datetime
      add :last_sign_in_at, :utc_datetime
      add :current_sign_in_ip, :string
      add :last_sign_in_ip, :string
      add :unlock_token, :string

      add :email_confirmation_token, :string
      add :email_confirmed_at,       :utc_datetime
      add :unconfirmed_email,        :string

      timestamps()
    end

    create unique_index(:users, :email_confirmation_token)
    create unique_index(:users, [:email])
  end
end
