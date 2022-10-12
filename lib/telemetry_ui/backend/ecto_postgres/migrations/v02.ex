defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V02 do
  @moduledoc false

  use Ecto.Migration

  def up(_) do
    alter table(:telemetry_ui_events) do
      add(:min_value, :float, null: true)
      add(:max_value, :float, null: true)
    end

    flush()

    execute("""
    UPDATE telemetry_ui_events SET min_value=value, max_value=value
    """)

    alter table(:telemetry_ui_events) do
      modify(:min_value, :float, null: false)
      modify(:max_value, :float, null: false)
    end
  end

  def down(_) do
    alter table(:telemetry_ui_events) do
      remove(:min_value)
      remove(:max_value)
    end
  end
end
