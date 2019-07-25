defmodule Boruta.Repo.Migrations.CreateBoruta do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:secret, :string)
      add(:redirect_uri, :string)
      add(:scope, :string)
      add(:authorize_scope, :boolean, default: false)
      add(:authorized_scopes, {:array, :string}, default: [])

      timestamps()
    end

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :string
      add :email, :string

      # authenticatable
      add :password_hash, :string
      # recoverable
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
      # lockable
      add :failed_attempts, :integer, default: 0
      add :locked_at, :utc_datetime
      # trackable
      add :sign_in_count, :integer, default: 0
      add :current_sign_in_at, :utc_datetime
      add :last_sign_in_at, :utc_datetime
      add :current_sign_in_ip, :string
      add :last_sign_in_ip, :string
      # unlockable_with_token
      add :unlock_token, :string

      timestamps()
    end

    create table(:tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:value, :string)
      add(:refresh_token, :string)
      add(:expires_at, :integer)
      add(:redirect_uri, :string)
      add(:state, :string)
      add(:scope, :string)

      add(:client_id, references("clients", type: :uuid))
      add(:resource_owner_id, references("users", type: :uuid))

      timestamps()
    end

    create unique_index(:users, [:email])

    create unique_index(:clients, [:id, :secret])
    create unique_index(:clients, [:id, :redirect_uri])
    create index("tokens", [:value])
    create unique_index("tokens", [:client_id, :value])
    create unique_index("tokens", [:client_id, :refresh_token])
  end
end
