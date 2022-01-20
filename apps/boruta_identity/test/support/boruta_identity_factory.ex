defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.RelyingParties.ClientRelyingParty
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.RelyingParties.Template

  def consent_factory do
    %Consent{
      client_id: SecureRandom.uuid(),
      scopes: []
    }
  end

  def client_relying_party_factory do
    %ClientRelyingParty{
      client_id: SecureRandom.uuid(),
      relying_party: build(:relying_party)
    }
  end

  def relying_party_factory do
    %RelyingParty{
      name: sequence(:name, &"Relying party #{&1}"),
      type: "internal"
    }
  end

  def template_factory do
    %Template{
      type: "new_registration",
      content: "new registration template content",
      relying_party: build(:relying_party)
    }
  end
end
