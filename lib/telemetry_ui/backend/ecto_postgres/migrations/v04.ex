defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V04 do
  @moduledoc false

  use Ecto.Migration

  def up(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    alter table(:telemetry_ui_events, prefix: prefix) do
      modify(:count, :bigint, null: false, default: 1)
    end
  end

  def down(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    alter table(:telemetry_ui_events, prefix: prefix) do
      modify(:count, :integer, null: false, default: 1)
    end
  end
end
