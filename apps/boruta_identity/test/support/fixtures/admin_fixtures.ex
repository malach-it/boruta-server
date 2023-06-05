defmodule BorutaIdentity.AdminFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaIdentity.Admin` context.
  """

  def role_fixture(attrs \\ %{}) do
    {:ok, role} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> BorutaIdentity.Admin.create_role()

    role
  end
end
