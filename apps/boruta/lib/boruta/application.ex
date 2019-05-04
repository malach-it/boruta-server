defmodule Boruta.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Boruta.Repo
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Boruta.Supervisor)
  end
end
