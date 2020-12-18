defmodule BorutaGateway.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :boruta_gateway,
    adapter: Ecto.Adapters.Postgres

  def listen(event_name) do
    with {:ok, pid} <- Postgrex.Notifications.start_link(__MODULE__.config()),
         {:ok, ref} <- Postgrex.Notifications.listen(pid, event_name) do
      {:ok, pid, ref}
    end
  end
end
