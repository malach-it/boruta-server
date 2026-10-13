defmodule BorutaGateway.Repo do
  @moduledoc false
  @backend Application.compile_env!(:boruta_gateway, :repo_backend)

  unless @backend in ["postgres", "mnesia"] do
    raise "BORUTA_GATEWAY_BACKEND must be postgres or mnesia"
  end

  @adapter if @backend == "mnesia",
             do: BorutaGateway.MnesiaAdapter,
             else: Ecto.Adapters.Postgres

  use Ecto.Repo,
    otp_app: :boruta_gateway,
    adapter: @adapter

  def backend, do: @backend

  def listen(event_name) do
    if @backend == "mnesia" do
      BorutaGateway.MnesiaListener.start_link(event_name, self())
    else
      with {:ok, pid} <- Postgrex.Notifications.start_link(__MODULE__.config()),
           {:ok, ref} <- Postgrex.Notifications.listen(pid, event_name) do
        {:ok, pid, ref}
      end
    end
  end
end
