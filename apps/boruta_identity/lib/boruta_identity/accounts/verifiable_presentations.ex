defmodule BorutaIdentity.Accounts.VerifiablePresentations do
  @moduledoc false

  alias BorutaIdentity.IdentityProviders.Backend

  def public_presentation_configuration do
    backend = Backend.default!()

    Enum.map(backend.verifiable_presentations, fn presentation ->
      {presentation["presentation_identifier"], %{}}
    end)
    |> Enum.into(%{})
  end
end
