defmodule BorutaIdentity.Accounts.VerifiablePresentations do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend

  def presentation_configuration(%User{backend: %Backend{} = backend}) do
    Enum.map(backend.verifiable_presentations, fn presentation ->
      {presentation["presentation_identifier"], %{
        definition: Jason.decode!(presentation["presentation_definition"])
      }}
    end)
    |> Enum.into(%{})
    |> Map.merge(public_presentation_configuration())
  end

  def presentation_configuration(_user) do
    public_presentation_configuration()
  end

  def public_presentation_configuration do
    backend = Backend.default!()

    Enum.map(backend.verifiable_presentations, fn presentation ->
      {presentation["presentation_identifier"], %{
        definition: Jason.decode!(presentation["presentation_definition"])
      }}
    end)
    |> Enum.into(%{})
  end
end
