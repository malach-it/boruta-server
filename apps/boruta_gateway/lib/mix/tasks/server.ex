defmodule Mix.Tasks.BorutaGateway.Server do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Application.put_env(:boruta_gateway, :server, true, persistent: true)

    Mix.Tasks.Run.run(["--no-halt"])
  end
end
