defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V03 do
  @moduledoc false

  use Ecto.Migration

  def up(%{prefix: prefix}) do
    execute("""
    DELETE FROM #{prefix || "public"}.telemetry_ui_events WHERE report_as IS NOT NULL
    """)

    drop_if_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags, :report_as], prefix: prefix))

    alter table(:telemetry_ui_events) do
      remove(:report_as, :string)
    end

    create_if_not_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags], prefix: prefix))
  end

  def down(%{prefix: prefix}) do
    drop_if_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags], prefix: prefix))

    alter table(:telemetry_ui_events) do
      add(:report_as, :string)
    end

    create_if_not_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags, :report_as], prefix: prefix))
  end
end
