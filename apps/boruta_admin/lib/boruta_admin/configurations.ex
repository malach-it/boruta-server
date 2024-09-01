defmodule BorutaAdmin.Configurations do
  @moduledoc false

  alias BorutaAdmin.Configurations.Configuration
  alias BorutaAdmin.Repo

  @spec upsert_configuration(name :: String.t(), value :: String.t()) ::
          {:ok, Configuration.t()} | {:error, Ecto.Changeset.t()}
  def upsert_configuration(name, value) do
    %Configuration{}
    |> Configuration.changeset(%{
      name: name,
      value: value
    })
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:name])
  end

  def list_configurations do
    Repo.all(Configuration)
  end

  def get_configuration(name) do
    Repo.get_by(Configuration, name: name)
  end
end
