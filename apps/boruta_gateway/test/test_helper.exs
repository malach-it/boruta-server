ExUnit.start()

case Process.whereis(BorutaGateway.Supervisor) do
  nil ->
    :ok

  _pid ->
    Supervisor.terminate_child(BorutaGateway.Supervisor, BorutaGateway.ServiceRegistry)
    Supervisor.delete_child(BorutaGateway.Supervisor, BorutaGateway.ServiceRegistry)
end
