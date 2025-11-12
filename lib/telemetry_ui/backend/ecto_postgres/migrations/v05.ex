defmodule TelemetryUI.Backend.EctoPostgres.Migrations.V05 do
  @moduledoc false

  use Ecto.Migration

  def up(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    execute("ALTER TABLE #{prefix}.telemetry_ui_events SET UNLOGGED")
  end

  def down(opts \\ %{}) do
    prefix = opts[:prefix] || "public"

    execute("ALTER TABLE #{prefix}.telemetry_ui_events SET LOGGED")
  end
end
