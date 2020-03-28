defmodule Boruta.Repo.Migrations.UpstreamsNotify do
  use Ecto.Migration

  def change do
    execute """
      CREATE OR REPLACE FUNCTION notify_upstreams_changes()
      RETURNS trigger AS $$
      DECLARE
        rec RECORD;
      BEGIN
        CASE TG_OP
        WHEN 'INSERT', 'UPDATE' THEN
           rec := NEW;
        WHEN 'DELETE' THEN
           rec := OLD;
        END CASE;

        PERFORM pg_notify(
          'upstreams_changed',
          json_build_object(
            'operation', TG_OP,
            'record', row_to_json(rec)
          )::text
        );

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    """

    execute """
      CREATE TRIGGER upstreams_changed
      AFTER INSERT OR UPDATE OR DELETE
      ON upstreams
      FOR EACH ROW
      EXECUTE PROCEDURE notify_upstreams_changes()
    """
  end
end
