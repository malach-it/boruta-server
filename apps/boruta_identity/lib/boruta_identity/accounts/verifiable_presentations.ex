defmodule BorutaIdentity.Accounts.VerifiablePresentations do
  @moduledoc false

  alias BorutaIdentity.IdentityProviders.Backend

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
