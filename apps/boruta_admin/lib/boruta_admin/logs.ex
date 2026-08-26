defmodule BorutaAdmin.Logs do
  @moduledoc """
  Reads and aggregates Boruta request and business-event logs through a configured backend.

  The filesystem backend is used by default. A different backend can be set
  with application configuration:

      config :boruta_admin, BorutaAdmin.Logs,
        adapter: MyApp.LogsAdapter,
        adapter_options: [custom_option: "value"]

  Backends implement `BorutaAdmin.Logs.Adapter` and own log retrieval, parsing,
  filtering, and aggregation.
  """

  @type request_query :: %{
          optional(:label | :method | :status_code | :text) => String.t() | nil
        }
  @type business_query :: %{
          optional(:action | :domain | :resource_id | :sub | :text) => String.t() | nil
        }
  @type query :: request_query() | business_query()

  @spec read(
          start_at :: DateTime.t(),
          end_at :: DateTime.t(),
          application :: atom(),
          type :: atom(),
          query :: query()
        ) :: map()
  def read(start_at, end_at, application, type, query) do
    {adapter, options} = adapter()
    adapter.read(start_at, end_at, application, type, query, options)
  end

  @spec earliest_at(application :: atom(), type :: atom()) :: DateTime.t()
  def earliest_at(application, type) do
    {adapter, options} = adapter()
    adapter.earliest_at(application, type, options)
  end

  defp adapter do
    config = Application.get_env(:boruta_admin, __MODULE__, [])
    adapter = Keyword.get(config, :adapter, BorutaAdmin.Logs.Adapters.File)
    {adapter, Keyword.merge(config, Keyword.get(config, :adapter_options, []))}
  end
end
