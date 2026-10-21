defmodule BorutaGateway.MnesiaSetup do
  @moduledoc false

  alias BorutaGateway.MnesiaRepo, as: Repo
  alias BorutaGateway.ServiceRegistry.Record
  alias BorutaGateway.Upstreams.Upstream

  def setup do
    case Repo.__adapter__().storage_up(Repo.config()) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      error -> raise "could not create gateway Mnesia storage: #{inspect(error)}"
    end

    migrations =
      Ecto.Adapters.Mnesia.Migrator.compile(
        schemas: [Upstream, Record],
        default_copy: :disc
      )

    {:ok, _, _} =
      Ecto.Adapters.Mnesia.Migrator.with_repo(Repo, fn repo ->
        Ecto.Adapters.Mnesia.Migrator.run(repo, migrations, sync: true)
      end)

    Enum.each([Upstream, Record], &check_table_shape!/1)

    :ok
  end

  def with_repo(fun) do
    Ecto.Adapters.Mnesia.Migrator.with_repo(Repo, fun)
  end

  defp check_table_shape!(schema) do
    source = Ecto.Adapters.Mnesia.Source.new(%{schema: schema})
    actual = :mnesia.table_info(source.table, :attributes)

    if actual != source.attributes do
      raise "Mnesia table #{source.table} does not match the gateway schema; migrate its data before starting this version"
    end
  end
end
