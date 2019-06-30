defmodule Mix.Tasks.Boruta.Gen.Migration do
  @moduledoc """
  Migration task for Boruta.

  Creates `clients`, `tokens` tables. It can also create migration for boruta coherence with `--with-coherence` arg.

  ## Examples
  ```
  mix boruta.gen.migration
  mix boruta.gen.migration --with-coherence
  ```

  ## Command line options
  - `--with-coherence` - creates Boruta coherence migration

  """

  use Mix.Task

  import Mix.Generator
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Generates Boruta migrations"

  @doc false
  def run(args) do
    no_umbrella!("boruta.gen.migration")
    repos = parse_repo(args)

    Enum.map repos, fn repo ->
      path = Path.join(source_repo_priv(repo), "migrations")
      file = Path.join(path, "#{timestamp()}_create_boruta.exs")
      assigns = [
        mod: Module.concat([repo, Migrations, "CreateBoruta"]),
        coherence: Enum.member?(args, "--with-coherence")
      ]

      fuzzy_path = Path.join(path, "*_create_boruta.exs")
      if Path.wildcard(fuzzy_path) != [] do
        Mix.raise "migration can't be created, there is already a migration file with name create_boruta."
      end

      create_file file, migration_template(assigns)
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  defp migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise "Expected :migration_module to be a module, got: #{inspect(other)}"
    end
  end

  embed_template :migration, """
  defmodule <%= inspect @mod %> do
    use <%= inspect migration_module() %>

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

      create table(:tokens, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:type, :string)
        add(:value, :string)
        add(:refresh_token, :string)
        add(:expires_at, :integer)
        add(:redirect_uri, :string)
        add(:state, :string)
        add(:scope, :string)

        add(:client_id, :uuid)
        add(:resource_owner_id, :uuid)

        timestamps()
      end
      <%= if @coherence do %>
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

      create unique_index(:users, [:email])
      <% end %>
      create unique_index(:clients, [:id, :secret])
      create unique_index(:clients, [:id, :redirect_uri])
      create index("tokens", [:value])
      create unique_index("tokens", [:client_id, :value])
      create unique_index("tokens", [:client_id, :refresh_token])
    end
  end
  """
end
