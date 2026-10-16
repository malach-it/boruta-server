defmodule BorutaGateway.MnesiaAdapter do
  @moduledoc false

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Queryable
  @behaviour Ecto.Adapter.Schema
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Transaction

  # ecto3_mnesia 0.3.0 implements Ecto.Adapter.Schema.delete/4, while the
  # umbrella's Ecto 3.11 calls delete/5. Keep this compatibility shim local.
  defmacro __before_compile__(_env), do: []

  defdelegate ensure_all_started(config, type), to: Ecto.Adapters.Mnesia
  defdelegate init(config), to: Ecto.Adapters.Mnesia
  defdelegate checkout(meta, options, fun), to: Ecto.Adapters.Mnesia
  defdelegate checked_out?(meta), to: Ecto.Adapters.Mnesia
  defdelegate dumpers(primitive, type), to: Ecto.Adapters.Mnesia
  defdelegate loaders(primitive, type), to: Ecto.Adapters.Mnesia
  defdelegate prepare(type, query), to: Ecto.Adapters.Mnesia
  defdelegate execute(meta, query_meta, query, params, opts), to: Ecto.Adapters.Mnesia
  defdelegate stream(meta, query_meta, query, params, opts), to: Ecto.Adapters.Mnesia
  defdelegate autogenerate(type), to: Ecto.Adapters.Mnesia

  defdelegate insert(meta, schema_meta, params, on_conflict, returning, opts),
    to: Ecto.Adapters.Mnesia

  defdelegate insert_all(
                meta,
                schema_meta,
                header,
                records,
                on_conflict,
                returning,
                placeholders,
                opts
              ),
              to: Ecto.Adapters.Mnesia

  defdelegate update(meta, schema_meta, params, filters, returning, opts),
    to: Ecto.Adapters.Mnesia

  def delete(meta, schema_meta, filters, _returning, opts),
    do: Ecto.Adapters.Mnesia.delete(meta, schema_meta, filters, opts)

  defdelegate in_transaction?(meta), to: Ecto.Adapters.Mnesia
  defdelegate transaction(meta, opts, fun), to: Ecto.Adapters.Mnesia
  defdelegate rollback(meta, value), to: Ecto.Adapters.Mnesia
  defdelegate storage_up(config), to: Ecto.Adapters.Mnesia
  defdelegate storage_down(config), to: Ecto.Adapters.Mnesia
  defdelegate storage_status(config), to: Ecto.Adapters.Mnesia
end
