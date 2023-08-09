defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V01 do
  @moduledoc false

  use Ecto.Migration

  def up(%{create_schema: create?, prefix: prefix} = opts) do
    %{quoted_prefix: quoted} = opts

    if create?, do: execute("CREATE SCHEMA IF NOT EXISTS #{quoted}")

    create_if_not_exists table(:telemetry_ui_events, primary_key: false, prefix: prefix) do
      add(:name, :string, null: false)
      add(:date, :utc_datetime_usec, null: false)
      add(:value, :float, null: false, default: 0.0)
      add(:count, :integer, null: false, default: 1)
      add(:tags, :jsonb, null: false, default: "{}")
      add(:report_as, :string)
    end

    create_if_not_exists(unique_index(:telemetry_ui_events, [:date, :name, :tags, :report_as], prefix: prefix))
  end

  def down(%{prefix: prefix}) do
    drop_if_exists(table(:telemetry_ui_events, prefix: prefix))
  end
end
