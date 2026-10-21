defmodule BorutaGateway.Repo do
  @moduledoc false

  def backend do
    case Application.fetch_env!(:boruta_gateway, :repo_backend) do
      backend when backend in ["postgres", "mnesia"] -> backend
      _ -> raise "BORUTA_GATEWAY_BACKEND must be postgres or mnesia"
    end
  end

  def repo do
    case backend() do
      "postgres" -> BorutaGateway.PostgresRepo
      "mnesia" -> BorutaGateway.MnesiaRepo
    end
  end

  for {name, arities} <- [
        all: [1, 2],
        one: [1, 2],
        one!: [1, 2],
        get: [2, 3],
        get!: [2, 3],
        get_by: [2, 3],
        get_by!: [2, 3],
        aggregate: [2, 3, 4],
        insert: [1, 2],
        insert!: [1, 2],
        update: [1, 2],
        update!: [1, 2],
        delete: [1, 2],
        delete!: [1, 2],
        insert_or_update: [1, 2],
        insert_or_update!: [1, 2],
        update_all: [2, 3],
        delete_all: [1, 2],
        transaction: [1, 2],
        rollback: [1],
        preload: [2, 3]
      ],
      arity <- arities do
    args = Macro.generate_arguments(arity, __MODULE__)

    def unquote(name)(unquote_splicing(args)) do
      apply(repo(), unquote(name), [unquote_splicing(args)])
    end
  end

  def config, do: repo().config()
  def __adapter__, do: repo().__adapter__()
  def get_dynamic_repo, do: repo().get_dynamic_repo()

  def listen(event_name) do
    if backend() == "mnesia" do
      BorutaGateway.MnesiaListener.start_link(event_name, self())
    else
      with {:ok, pid} <- Postgrex.Notifications.start_link(config()),
           {:ok, ref} <- Postgrex.Notifications.listen(pid, event_name) do
        {:ok, pid, ref}
      end
    end
  end
end
