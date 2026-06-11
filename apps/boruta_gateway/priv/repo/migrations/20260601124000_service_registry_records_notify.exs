defmodule BorutaGateway.Repo.Migrations.ServiceRegistryRecordsNotify do
  use Ecto.Migration

  def up do
    execute("""
      CREATE OR REPLACE FUNCTION notify_service_registry_records_changes()
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
          'service_registry_records_changed',
          json_build_object(
            'operation', TG_OP,
            'record', row_to_json(rec)
          )::text
        );

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("""
      DROP TRIGGER IF EXISTS service_registry_records_changed
      ON service_registry_records
    """)

    execute("""
      CREATE TRIGGER service_registry_records_changed
      AFTER INSERT OR UPDATE OR DELETE
      ON service_registry_records
      FOR EACH ROW
      EXECUTE PROCEDURE notify_service_registry_records_changes()
    """)
  end

  def down do
    execute("""
      DROP TRIGGER IF EXISTS service_registry_records_changed
      ON service_registry_records
    """)

    execute("DROP FUNCTION IF EXISTS notify_service_registry_records_changes()")
  end
end
