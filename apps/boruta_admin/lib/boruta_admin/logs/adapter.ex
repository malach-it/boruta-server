defmodule BorutaAdmin.Logs.Adapter do
  @moduledoc """
  Backend contract used by `BorutaAdmin.Logs`.

  A backend owns log retrieval, parsing, filtering, and aggregation. The
  configured backend is called through `BorutaAdmin.Logs`.
  """

  @callback earliest_at(application :: atom(), type :: atom(), options :: keyword()) ::
              DateTime.t()

  @callback read(
              start_at :: DateTime.t(),
              end_at :: DateTime.t(),
              application :: atom(),
              type :: atom(),
              query :: BorutaAdmin.Logs.query(),
              options :: keyword()
            ) :: map()
end
