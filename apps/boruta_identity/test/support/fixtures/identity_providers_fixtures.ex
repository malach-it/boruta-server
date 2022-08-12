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
        password_hashing_alg: "some password_hashing_alg",
        password_hashing_salt: "some password_hashing_salt",
        type: "some type"
      })
      |> BorutaIdentity.IdentityProviders.create_backend()

    backend
  end
end
