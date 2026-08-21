defmodule BorutaAdmin.Logs.Adapter do
  @moduledoc """
  Backend contract used by `BorutaAdmin.Logs`.

  An adapter returns the raw, formatted log lines. Parsing, filtering and
  aggregation remain the responsibility of `BorutaAdmin.Logs`.
  """

  @callback earliest_at(application :: atom(), type :: atom(), options :: keyword()) ::
              DateTime.t()

  @callback stream(
              start_at :: DateTime.t(),
              end_at :: DateTime.t(),
              application :: atom(),
              type :: atom(),
              query :: map(),
              options :: keyword()
            ) :: Enumerable.t()

  @callback aggregate(
              start_at :: DateTime.t(),
              end_at :: DateTime.t(),
              application :: atom(),
              type :: atom(),
              query :: map(),
              parsed_stats :: map(),
              options :: keyword()
            ) :: map()

  @optional_callbacks aggregate: 7
end
