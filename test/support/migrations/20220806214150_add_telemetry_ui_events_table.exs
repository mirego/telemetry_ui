defmodule TelemetryUI.Test.Repo.Migrations.AddTelemetryUIEventsTable do
  use Ecto.Migration

  defdelegate up, to: TelemetryUI.Backend.EctoPostgres.Migrations

  def down do
    TelemetryUI.Backend.EctoPostgres.Migrations.down(version: 1)
  end
end
