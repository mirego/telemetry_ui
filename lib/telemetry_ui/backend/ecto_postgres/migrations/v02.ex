defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V02 do
  @moduledoc false

  use Ecto.Migration

  def up(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    alter table(:telemetry_ui_events, prefix: prefix) do
      add(:min_value, :float, null: true)
      add(:max_value, :float, null: true)
    end

    flush()

    execute("""
    UPDATE #{prefix}.telemetry_ui_events SET min_value=value, max_value=value
    """)

    alter table(:telemetry_ui_events, prefix: prefix) do
      modify(:min_value, :float, null: false)
      modify(:max_value, :float, null: false)
    end
  end

  def down(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    alter table(:telemetry_ui_events, prefix: prefix) do
      remove(:min_value)
      remove(:max_value)
    end
  end
end
