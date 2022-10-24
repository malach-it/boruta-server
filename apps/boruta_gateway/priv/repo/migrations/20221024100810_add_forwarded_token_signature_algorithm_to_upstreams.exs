defmodule BorutaGateway.Repo.Migrations.AddForwardedTokenSignatureAlgorithmToUpstreams do
  use Ecto.Migration

  def change do
    alter table(:upstreams) do
      add :forwarded_token_signature_alg, :string
    end
  end
end
