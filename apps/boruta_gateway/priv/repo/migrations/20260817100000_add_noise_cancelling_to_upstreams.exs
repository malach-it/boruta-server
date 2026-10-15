defmodule BorutaGateway.Repo.Migrations.AddNoiseCancellingToUpstreams do
  use Ecto.Migration

  def up do
    alter table(:upstreams) do
      add(:noise_cancelling_enabled, :boolean, null: false, default: false)
      add(:noise_cancelling_model, :binary)
    end

    execute(notification_function("'record', to_jsonb(rec) - 'noise_cancelling_model'"))
  end

  def down do
    execute(notification_function("'record', row_to_json(rec)"))

    alter table(:upstreams) do
      remove(:noise_cancelling_enabled)
      remove(:noise_cancelling_model)
    end
  end

  defp notification_function(record) do
    """
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
          #{record}
        )::text
      );

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
  end
end
