defmodule Mix.Tasks.Boruta.Server do
  @moduledoc false

  use Mix.Task

  def run(args) do
    Application.put_env(:boruta_gateway, :server, true, persistent: true)
    Mix.Tasks.Phx.Server.run(args)
  end
end
