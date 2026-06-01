defmodule BorutaGateway.Repo.Migrations.ShrinkServiceRegistryRecordNotifications do
  use Ecto.Migration

  def up do
    execute("""
      CREATE OR REPLACE FUNCTION notify_service_registry_records_changes()
      RETURNS trigger AS $$
      DECLARE
        record_id uuid;
      BEGIN
        CASE TG_OP
        WHEN 'INSERT', 'UPDATE' THEN
          record_id := NEW.id;
        WHEN 'DELETE' THEN
          record_id := OLD.id;
        END CASE;

        PERFORM pg_notify(
          'service_registry_records_changed',
          json_build_object(
            'operation', TG_OP,
            'record', json_build_object('id', record_id)
          )::text
        );

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    """)
  end

  def down do
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
  end
end
