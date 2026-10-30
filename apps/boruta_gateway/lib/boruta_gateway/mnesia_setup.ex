defmodule BorutaGateway.MnesiaSetup do
  @moduledoc false

  alias Boruta.Ecto.AuthorizationRequest
  alias Boruta.Ecto.Client
  alias Boruta.Ecto.Credential
  alias Boruta.Ecto.Scope
  alias Boruta.Ecto.Token
  alias BorutaGateway.MnesiaRepo, as: Repo
  alias BorutaGateway.ServiceRegistry.Record
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.Mnesia.Migrator
  alias Ecto.Adapters.Mnesia.Source

  def setup do
    case Repo.__adapter__().storage_up(Repo.config()) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      error -> raise "could not create gateway Mnesia storage: #{inspect(error)}"
    end

    schemas = [
      AuthorizationRequest,
      Client,
      Credential,
      Record,
      Scope,
      Token,
      Upstream
    ]

    migrations =
      Migrator.compile(
        schemas: schemas,
        default_copy: :disc
      )

    {:ok, _, _} =
      Migrator.with_repo(Repo, fn repo ->
        Migrator.run(repo, migrations, sync: true)
      end)

    Enum.each(schemas, &check_table_shape!/1)

    :ok
  end

  def with_repo(fun) do
    Migrator.with_repo(Repo, fun)
  end

  defp check_table_shape!(schema) do
    source = Source.new(%{schema: schema})
    actual = :mnesia.table_info(source.table, :attributes)

    if actual != source.attributes do
      raise "Mnesia table #{source.table} does not match the gateway schema; migrate its data before starting this version"
    end
  end
end
