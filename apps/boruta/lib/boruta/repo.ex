defmodule Boruta.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :boruta,
    adapter: Ecto.Adapters.Postgres

  def reload(%module{id: id}) do
    get(module, id)
  end
end
