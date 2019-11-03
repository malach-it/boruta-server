defmodule Boruta.Repo.Migrations.ChangeRedirectUriToRedirectUris do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE clients
    ALTER COLUMN redirect_uri
      TYPE character varying(255)[]
      USING ARRAY[redirect_uri]
    """
    rename table(:clients), :redirect_uri, to: :redirect_uris
  end

  def down do
    rename table(:clients), :redirect_uris, to: :redirect_uri
    execute """
    ALTER TABLE clients
    ALTER COLUMN redirect_uri
      TYPE character varying(255)
      USING redirect_uri[1]
    """
  end
end
