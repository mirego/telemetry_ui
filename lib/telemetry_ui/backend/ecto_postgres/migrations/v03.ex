defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V03 do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    execute("""
    DELETE FROM #{prefix}.telemetry_ui_events WHERE report_as IS NOT NULL
    """)

    drop_if_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags, :report_as], prefix: prefix, concurrently: true))

    alter table(:telemetry_ui_events) do
      remove(:report_as, :string)
    end

    create_if_not_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags], prefix: prefix, concurrently: true))
  end

  def down(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    drop_if_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags], prefix: prefix, concurrently: true))

    alter table(:telemetry_ui_events) do
      add(:report_as, :string)
    end

    create_if_not_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags, :report_as], prefix: prefix, concurrently: true))
  end
end
