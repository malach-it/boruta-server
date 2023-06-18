defmodule BorutaGateway.ServiceRegistryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaGateway.ServiceRegistry` context.
  """

  alias BorutaGateway.ServiceRegistry.Node

  @doc """
  Generate a node.
  """
  def node_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        ip: "some ip",
        name: "some name"
      })

    %Node{}
    |> Node.changeset(attrs)
    |> BorutaGateway.Repo.insert!()
  end
end
