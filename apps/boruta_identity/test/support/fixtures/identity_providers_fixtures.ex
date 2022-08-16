defmodule BorutaIdentity.IdentityProvidersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaIdentity.IdentityProviders` context.
  """

  @doc """
  Generate a backend.
  """
  def backend_fixture(attrs \\ %{}) do
    {:ok, backend} =
      attrs
      |> Enum.into(%{
        type: "Elixir.BorutaIdentity.Accounts.Internal",
        name: "some name"
      })
      |> BorutaIdentity.IdentityProviders.create_backend()

    backend
  end
end
