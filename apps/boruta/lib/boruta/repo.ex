defmodule Boruta.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :boruta,
    adapter: Ecto.Adapters.Postgres
end
