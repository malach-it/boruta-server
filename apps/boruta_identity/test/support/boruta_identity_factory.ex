defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.Consent

  def consent_factory do
    %Consent{
      client_id: SecureRandom.uuid(),
      scopes: []
    }
  end
end
